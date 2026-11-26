using System;
using System.Collections.Generic;
using System.Linq;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// MBA-1007 / MBA-1008, for a multi-channel logger: which sensor's certificate compensates each channel,
    /// loading the certificates without blocking the poll, and telling the operator once when a channel is held
    /// back for want of one.
    /// <para>
    /// The rules are the ones <see cref="Hydra2DeviceBL"/> arrived at on the bench, taken out of it so a second
    /// logger obeys them too (MBA-1058, the DAQ-9600). Hydra2DeviceBL still carries its own copy: moving it onto
    /// this class is a separate change to a verified BL.
    /// </para>
    /// <list type="bullet">
    /// <item>A missing certificate is loaded in the background, never on the poll thread: a load is two queries of
    /// up to 30 s, and the 60 s data watchdog would reset a working logger.</item>
    /// <item>"No certificate on file" is an answer and is not asked again until the next init or association. A
    /// failed read is not: it is retried every <see cref="RetryInterval"/>.</item>
    /// <item>Held-back channels are logged once per sensor per init, and alerted (CorrectionUnavailable) once per
    /// sensor and reason, only once the reason is settled.</item>
    /// </list>
    /// </summary>
    public sealed class ChannelCertificates
    {
        private readonly HydraCalculations _hc;
        private readonly string _logTag;
        private readonly Action<string, string, string> _raiseAlert;

        private readonly object _lock = new object();
        private readonly object _loadLock = new object();
        private readonly HashSet<string> _loading = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, DateTime> _retryUtc = new Dictionary<string, DateTime>(StringComparer.OrdinalIgnoreCase);
        /// <summary>"sensor|outcome" already logged this init, so a changed reason gets its own line.</summary>
        private readonly HashSet<string> _reported = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        /// <summary>Per sensor, the outcome last alerted.</summary>
        private readonly Dictionary<string, Outcome> _alerted = new Dictionary<string, Outcome>(StringComparer.OrdinalIgnoreCase);

        /// <summary>Why the BL held a channel back.</summary>
        public enum HoldReason
        {
            /// <summary>No sensor associated with the channel, and none in the settings file.</summary>
            NoSensor,
            /// <summary>The sensor's correction certificate is not loaded (still loading, failed to read, or none on file).</summary>
            Certificate,
            /// <summary>PT-100: the sensor has no ITS-90 coefficients on file (CalcResistanceToTemperatureITS90 refused).</summary>
            NoCoefficients,
            /// <summary>The certificate is loaded and still refused this value (WrongValue).</summary>
            ConversionFailed,
        }

        /// <summary>A held-back channel: its sensor (null for <see cref="HoldReason.NoSensor"/>) and why.</summary>
        public struct HeldBack
        {
            public HeldBack(string sensor, HoldReason reason) { Sensor = sensor; Reason = reason; }
            public string Sensor { get; }
            public HoldReason Reason { get; }
        }

        /// <summary>What the operator is told. Every outcome but <see cref="Loading"/> is settled and is alerted.</summary>
        public enum Outcome
        {
            Loading,
            ReadFailed,
            NoneOnFile,
            NoSensor,
            NoCoefficients,
            ConversionFailed,
        }

        /// <summary>
        /// The outcome for one held-back channel. Only a certificate still being fetched is unsettled; the others are
        /// answers, alerted at once (PR #76 review: a PT-100 without coefficients used to be held back silently,
        /// logged as "certificate not loaded yet").
        /// </summary>
        internal static Outcome Settle(HoldReason reason, bool noneOnFile, bool readFailed)
        {
            switch (reason)
            {
                case HoldReason.NoSensor: return Outcome.NoSensor;
                case HoldReason.NoCoefficients: return Outcome.NoCoefficients;
                case HoldReason.ConversionFailed: return Outcome.ConversionFailed;
            }
            if (noneOnFile) return Outcome.NoneOnFile;
            return readFailed ? Outcome.ReadFailed : Outcome.Loading;
        }

        /// <summary>The server.log reason for an outcome.</summary>
        internal static string LogText(Outcome outcome)
        {
            switch (outcome)
            {
                case Outcome.NoSensor: return "no sensor associated and none in the settings file - not sent";
                case Outcome.NoneOnFile: return "no correction certificate on file - not sent until one is saved and the logger is confirmed again";
                case Outcome.ReadFailed: return "correction certificate could not be read - retrying, not sent until it loads";
                case Outcome.NoCoefficients: return "no ITS-90 coefficients on file for this PT-100 - not sent until they are saved and the logger is confirmed again";
                case Outcome.ConversionFailed: return "the certificate refused this reading - not sent";
                default: return "correction certificate not loaded yet - not sent until it is";
            }
        }

        /// <summary>The text after "Channel n not sent - " in the CorrectionUnavailable alert.</summary>
        internal static string AlertText(Outcome outcome, string sensor)
        {
            switch (outcome)
            {
                case Outcome.NoSensor: return "has no sensor associated";
                case Outcome.NoneOnFile: return "sensor " + sensor + " has no correction certificate on file";
                case Outcome.NoCoefficients: return "sensor " + sensor + " has no ITS-90 coefficients on file";
                case Outcome.ConversionFailed: return "sensor " + sensor + " certificate refused the reading";
                default: return "sensor " + sensor + " correction certificate could not be read - retrying";
            }
        }

        /// <summary>How soon a certificate whose load failed is tried again.</summary>
        public static readonly TimeSpan RetryInterval = TimeSpan.FromSeconds(30);

        /// <param name="raiseAlert">(alertType, message, channel) - the host's RaiseAlert.</param>
        public ChannelCertificates(HydraCalculations hc, string logTag, Action<string, string, string> raiseAlert)
        {
            _hc = hc;
            _logTag = logTag;
            _raiseAlert = raiseAlert;
        }

        /// <summary>
        /// The sensor whose certificate compensates <paramref name="channel"/>: the one the operator associated,
        /// or the settings file's master for a client that never associated one. Null when there is neither.
        /// </summary>
        public static string SensorFor(int channel, ChannelMasterMap sensors, IList<string> fileMasters)
        {
            var map = sensors ?? ChannelMasterMap.Empty;
            var sensor = map.IsEmpty ? fileMasters?.FirstOrDefault() : map.MasterFor(channel);
            return string.IsNullOrWhiteSpace(sensor) ? null : sensor.Trim();
        }

        /// <summary>Every init: loads all the certificates it will need before the first scan (blocking, as Hydra2 does).</summary>
        public void LoadForInit(IEnumerable<string> fileMasters, ChannelMasterMap sensors)
        {
            var certificates = (fileMasters ?? Enumerable.Empty<string>())
                .Concat((sensors ?? ChannelMasterMap.Empty).AllMasters())
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
            lock (_lock)
            {
                _retryUtc.Clear();
                _reported.Clear();
                // _alerted is kept: a re-init alone does not change what the operator was told
            }
            lock (_loadLock)
            {
                _hc.Init(certificates).GetAwaiter().GetResult();
            }
            lock (_lock)
            {
                foreach (var sensor in certificates.Where(_hc.HasCorrectionValues)) _alerted.Remove(sensor);
            }
        }

        /// <summary>
        /// Whether <paramref name="sensor"/>'s certificate is loaded. When it is not, and the database has not
        /// answered "none on file", a background load is started and this scan goes without it.
        /// </summary>
        public bool Ensure(string sensor)
        {
            if (string.IsNullOrWhiteSpace(sensor)) return false;
            if (_hc.HasCorrectionValues(sensor)) return true;
            if (_hc.IsKnownToHaveNoCorrections(sensor)) return false;

            lock (_lock)
            {
                if (_loading.Contains(sensor)) return false;
                if (_retryUtc.TryGetValue(sensor, out var retryAt) && DateTime.UtcNow < retryAt) return false;
                _loading.Add(sensor);
            }
            System.Threading.Tasks.Task.Run(() => Load(sensor));
            return false;
        }

        /// <summary>The app associated sensors: each is asked about afresh and fetched now, in the background.</summary>
        public void OnAssociated(ChannelMasterMap sensors)
        {
            foreach (var sensor in (sensors ?? ChannelMasterMap.Empty).AllMasters())
            {
                if (string.IsNullOrWhiteSpace(sensor) || _hc.HasCorrectionValues(sensor)) continue;
                _hc.ForgetNoCorrectionsOnFile(sensor);
                lock (_lock)
                {
                    _retryUtc.Remove(sensor);
                    ForgetReported(sensor);
                    _alerted.Remove(sensor);
                }
                Ensure(sensor);
            }
        }

        private void Load(string sensor)
        {
            try
            {
                lock (_loadLock)
                {
                    _hc.Init(new List<string> { sensor }).GetAwaiter().GetResult();
                }
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[{0} Correction] Sensor '{1}': loading its certificate failed: {2}", _logTag, sensor, ex.Message);
            }
            finally
            {
                var loaded = _hc.HasCorrectionValues(sensor);
                var none = !loaded && _hc.IsKnownToHaveNoCorrections(sensor);
                lock (_lock)
                {
                    _loading.Remove(sensor);
                    if (loaded || none) _retryUtc.Remove(sensor);
                    else _retryUtc[sensor] = DateTime.UtcNow + RetryInterval;
                    ForgetReported(sensor);
                    if (loaded) _alerted.Remove(sensor);
                }
                Libs.Trace.Tracer.Info(loaded
                    ? "[{0} Correction] Sensor '{1}': correction certificate loaded"
                    : none
                        ? "[{0} Correction] Sensor '{1}': no correction certificate on file"
                        : "[{0} Correction] Sensor '{1}': certificate could not be read - retrying in {2:F0} s",
                    _logTag, sensor, RetryInterval.TotalSeconds);
            }
        }

        private void ForgetReported(string sensor)
        {
            var prefix = sensor + "|";
            _reported.RemoveWhere(k => k.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// One log line per sensor and reason per init for the channels held back, and a CorrectionUnavailable alert
        /// per channel once per sensor and outcome, as soon as the outcome is settled (<see cref="Settle"/>).
        /// </summary>
        public void ReportHeldBack(IDictionary<int, HeldBack> heldBack)
        {
            if (heldBack == null || heldBack.Count == 0) return;

            foreach (var group in heldBack.GroupBy(kv => new { Sensor = kv.Value.Sensor ?? "", kv.Value.Reason }))
            {
                var sensor = group.Key.Sensor;
                var channels = group.Select(kv => kv.Key).OrderBy(c => c).ToList();
                Outcome outcome;
                bool first, alert;
                lock (_lock)
                {
                    var none = sensor.Length > 0 && _hc.IsKnownToHaveNoCorrections(sensor);
                    outcome = Settle(group.Key.Reason, none, sensor.Length > 0 && _retryUtc.ContainsKey(sensor));
                    first = _reported.Add(sensor + "|" + outcome);
                    alert = outcome != Outcome.Loading && (!_alerted.TryGetValue(sensor, out var told) || told != outcome);
                    if (alert) _alerted[sensor] = outcome;
                }

                if (first)
                {
                    Libs.Trace.Tracer.Info("[{0} Correction] CH{1} | NOT SENT: sensor '{2}': {3}",
                        _logTag, string.Join(",", channels), sensor, LogText(outcome));
                }

                if (!alert || _raiseAlert == null) continue;
                var text = AlertText(outcome, sensor);
                foreach (var channel in channels)
                {
                    _raiseAlert("CorrectionUnavailable",
                        string.Format("Channel {0} not sent - {1}", channel, text),
                        channel.ToString(System.Globalization.CultureInfo.InvariantCulture));
                }
            }
        }
    }

    /// <summary>
    /// MBA-962 / MBA-967, for a multi-channel logger: which channels the app has been told are down, so each
    /// disconnect and each return is announced once, on the transition. Kept across re-inits and reconnects (the
    /// app keeps a channel shaded until a DataRestored on that exact channel). Taken from Hydra2DeviceBL.
    /// </summary>
    public sealed class ChannelDisconnects
    {
        private readonly HashSet<int> _down = new HashSet<int>();
        private readonly string _logTag;
        private readonly Action<string, string, string> _raiseAlert;

        public ChannelDisconnects(string logTag, Action<string, string, string> raiseAlert)
        {
            _logTag = logTag;
            _raiseAlert = raiseAlert;
        }

        /// <summary>The channel reads its open-input value. Alerts once, on the way in.</summary>
        public void Disconnected(int channel)
        {
            lock (_down) { if (!_down.Add(channel)) return; }
            Libs.Trace.Tracer.Info("[{0}] CH{1} is reading the open-input value - no sensor connected. " +
                                   "It is excluded from the broadcast and from the calibration.", _logTag, channel);
            _raiseAlert?.Invoke("ChannelDisconnected",
                string.Format("Channel {0} disconnected - no sensor detected", channel),
                channel.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }

        /// <summary>The channel reads again. Same channel number on the DataRestored, which is what the app closes on.</summary>
        public void Restored(int channel)
        {
            lock (_down) { if (!_down.Remove(channel)) return; }
            Libs.Trace.Tracer.Info("[{0}] CH{1} is reading again - sensor reconnected.", _logTag, channel);
            _raiseAlert?.Invoke("DataRestored",
                string.Format("Channel {0} reconnected - readings resumed", channel),
                channel.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }

        /// <summary>A down channel the new configuration no longer scans is closed now - no scan will ever restore it.</summary>
        public void ForgetNotScanned(IEnumerable<int> scanned)
        {
            var keep = new HashSet<int>(scanned ?? Enumerable.Empty<int>());
            List<int> dropped;
            lock (_down)
            {
                dropped = _down.Where(ch => !keep.Contains(ch)).OrderBy(ch => ch).ToList();
                foreach (var ch in dropped) _down.Remove(ch);
            }
            foreach (var channel in dropped)
            {
                Libs.Trace.Tracer.Info("[{0}] CH{1} was disconnected and is no longer scanned - closing its alert.", _logTag, channel);
                _raiseAlert?.Invoke("DataRestored",
                    string.Format("Channel {0} removed from the scan - no longer monitored", channel),
                    channel.ToString(System.Globalization.CultureInfo.InvariantCulture));
            }
        }
    }
}
