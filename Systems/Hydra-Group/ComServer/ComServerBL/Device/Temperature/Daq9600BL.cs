using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// GW Instek DAQ-9600 data-acquisition mainframe with DAQ-901 multiplexer cards, used as a multi-channel
    /// temperature logger (MBA-1058). Supersedes the never-finished <c>InstekDeviceBL</c>, whose
    /// <c>TRIG:COUN INF</c> + <c>READ?</c> could never return a reading.
    /// <para>
    /// Setup (<see cref="Daq9600Readings.SetupCommands"/>) is one chain - each command is sent when the one
    /// before it has gone out - ending in <c>SYST:ERR?</c>, whose answer is logged. Then one <c>READ?</c> per
    /// <see cref="HardwareBL_DeviceType.Interval"/> seconds: one sweep of the scan list, one value per channel.
    /// </para>
    /// <para>
    /// Each channel is handled as Hydra2DeviceBL handles its channels: an open input (9.9E37) is a disconnect,
    /// alerted once; a thermocouple reading is compensated with the certificate of the sensor the operator
    /// associated with that channel, and held back - never sent uncorrected - when there is none; a PT-100 is
    /// read as ohms and converted with that sensor's ITS-90 coefficients; DC volts go out as measured.
    /// </para>
    /// Verified on 2026-11-26 against GEY150853 (31-83) over USBTMC: identification, every setup command, and
    /// five K thermocouples on 101-105. See docs/devices/temperature/GW-Instek-DAQ-9600/protocol.md.
    /// </summary>
    public class Daq9600BL : CommonBL.BaseBLDevice
    {
        #region constants

        public const int STATE_MACHINE__Setup = 1;
        public const int STATE_MACHINE__Logs = 2;

        /// <summary>This BL's key in <see cref="HardwareBL_Settings"/> - the operator's configuration is routed by it.</summary>
        public const string SETTINGS_FAMILY = "Daq9600";

        public override string SettingsFamily => SETTINGS_FAMILY;

        private const string Tag = "DAQ-9600";

        /// <summary>The shortest poll period, whatever the settings say.</summary>
        internal static readonly TimeSpan MinimumInterval = TimeSpan.FromSeconds(1);

        #endregion

        #region fields

        private readonly HydraCalculations HC;
        private readonly HardwareBL_Settings settings;
        private readonly ChannelCertificates _certificates;
        private readonly ChannelDisconnects _disconnects;

        public CommonBL.SingleState StateMachine_Setup { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }

        /// <summary>
        /// Which polling loop is the live one (as in Hydra2DeviceBL, MBA-967). Every init and every stop moves it
        /// on, and a loop asleep in its interval wait stops at its next step instead of polling beside the new one.
        /// </summary>
        private int _generation;

        /// <summary>The scan of the current init: instrument channels, ascending - the order READ? answers in.</summary>
        private List<int> _scan = new List<int>();
        private Daq9600Function _function = Daq9600Function.Unsupported;
        private int _consecutiveFailures;

        #endregion

        #region ctor

        public Daq9600BL(Daq9600BLCore parent) : base(parent)
        {
            HC = new HydraCalculations(new ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository());
            settings = parent.DeviceSettings;
            Action<string, string, string> alert = (type, message, channel) => HW_Device?.RaiseAlert(type, message, channel);
            _certificates = new ChannelCertificates(HC, Tag, alert);
            _disconnects = new ChannelDisconnects(Tag, alert);
            settings.Daq9600.ChannelMastersChanged += _certificates.OnAssociated;
        }

        #endregion

        #region BaseBLDevice

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            Interlocked.Increment(ref _generation);
            _consecutiveFailures = 0;

            HardwareBL_Settings.RegisterActiveFamily(SETTINGS_FAMILY);

            // MBA-967: the operator's first Confirm arrives before this BL exists and is held; applied here, before
            // the setup reads the settings, so the first init already scans the operator's channels.
            var held = settings.ApplyPendingWebSocketConfig(SETTINGS_FAMILY, DateTime.UtcNow, out var ambiguous);
            if (held != null)
                Libs.Trace.Tracer.Info("[WS->HW] Applied the configuration received before the logger was identified: {0}", held);
            else if (ambiguous != null)
                Libs.Trace.Tracer.Info("[WS->HW] Configurations for loggers {0} were held before any logger was identified; " +
                                       "cannot tell which is this one, so none was applied. Using the current settings until the next Confirm.", ambiguous);

            var family = FillMissingFromDefaults(settings.Daq9600);
            _function = Daq9600Readings.FunctionFor(family.Sensor);
            _scan = Daq9600Readings.ScanOrder(family.Channels, _function, out var rejected);
            if (rejected.Count > 0)
                Libs.Trace.Tracer.Info("[{0}] Channels {1} are not scanned: {2}", Tag, string.Join(",", rejected),
                    _function == Daq9600Function.Pt100FourWire
                        ? "a 4-wire channel must be terminal 1-10 of a card (it pairs with terminal n+10)"
                        : "outside 1-" + Daq9600Readings.MaxChannels);

            _disconnects.ForgetNotScanned(_scan.Select(Daq9600Readings.ToAppChannel));
            _certificates.LoadForInit(family.Masters, family.ChannelMasters);

            if (StateMachine_Setup == null)
            {
                StateMachine_Setup = new CommonBL.SingleState(STATE_MACHINE__Setup, "Setup")
                {
                    Action_DoWork = StateWork__Setup,
                    DefaultTimeOut = TimeSpan.FromSeconds(30)
                };
            }
            if (StateMachine_Logs == null)
            {
                StateMachine_Logs = new CommonBL.SingleState(STATE_MACHINE__Logs, "Logs")
                {
                    Action_DoWork = StateWork__Logs
                };
            }
            StateMachine_Setup.IsActive = true;
            StateMachine_Logs.IsActive = true;

            return new[] { StateMachine_Setup, StateMachine_Logs };
        }

        protected override bool OnStepStart(DeviceSteps step)
        {
            switch (step)
            {
                case DeviceSteps.Start:
                case DeviceSteps.Close:
                    return true;
            }
            return false;
        }

        public override void OnEvent(DeviceEventArgs e)
        {
            base.OnEvent(e);
        }

        /// <summary>The DAQ-9600 is polled, so stopping is: no further READ?, and ABOR for a sweep in progress.</summary>
        public override bool CanStopScanning => true;

        public override bool StopScanning(string reason)
        {
            HaltStateMachine();
            var generation = Interlocked.Increment(ref _generation);
            Libs.Trace.Tracer.Info("[{0}] Stopping the scan ({1}): every polling loop before #{2} stops", Tag, reason, generation);
            if (HW_Device != null && HW_Device.IsConnected)
                HW_Device.Reset(new InitSystemRequest { Packet = new HardwarePacket("ABOR", false) });
            return true;
        }

        #endregion

        #region settings

        /// <summary>
        /// MBA-1058 (ticket finding 6): a station's HydraBL_Settings.json is kept across upgrades and the installer's
        /// copy predates this family, so the Daq9600 bucket is the empty constructor object there - no channels, no
        /// sensor, no interval. Each missing field is taken from <see cref="HardwareBL_Settings.CreateDefaultSettings"/>
        /// rather than letting the setup run with nulls.
        /// </summary>
        internal static HardwareBL_DeviceType FillMissingFromDefaults(HardwareBL_DeviceType family)
        {
            var defaults = HardwareBL_Settings.CreateDefaultSettings().Daq9600;
            if (family.Channels == null || family.Channels.Count == 0) family.Channels = new List<int>(defaults.Channels);
            if (family.Sensor == null) family.Sensor = defaults.Sensor;
            if (family.Interval <= 0) family.Interval = defaults.Interval;
            if (family.MaxNumOfChannels <= 0) family.MaxNumOfChannels = defaults.MaxNumOfChannels;
            if (family.Masters == null) family.Masters = new List<string>();
            return family;
        }

        #endregion

        #region setup

        private CommonBL.SingleState.StepWorkResponses StateWork__Setup(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var commands = Daq9600Readings.SetupCommands(_function, settings.Daq9600.Sensor, _scan, settings.Daq9600.MeasurementRate);
                    if (commands == null)
                    {
                        Libs.Trace.Tracer.Info("[{0}] Nothing to set up: function {1}, {2} channel(s) - no readings until the settings name " +
                                               "a thermocouple (K/T/R/S), a PT-100 or DC volts on at least one channel", Tag, _function, _scan.Count);
                        return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                    }
                    Libs.Trace.Tracer.Info("[{0}] Setting up {1} on {2}", Tag, _function, Daq9600Readings.ChannelList(_scan));
                    SendSetup(commands, 0, Volatile.Read(ref _generation));
                    return CommonBL.SingleState.StepWorkResponses.Wait4Work;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>Sends commands[index]; its completion sends the next, so two never overlap on the link.</summary>
        private void SendSetup(List<string> commands, int index, int generation)
        {
            if (Volatile.Read(ref _generation) != generation || HW_Device == null || !HW_Device.IsConnected) return;
            if (index >= commands.Count)
            {
                StateMachine_Setup.NextStepFrom(0);
                return;
            }

            var command = commands[index];
            var isQuery = command.IndexOf('?') >= 0;
            var request = new InitSystemRequest { Packet = new HardwarePacket(command, isQuery) };
            HW_Device.Reset(request, res =>
            {
                if (isQuery)
                {
                    var reply = res?.Message;
                    if (res != null && res.Result && Daq9600Readings.IsNoError(reply))
                        Libs.Trace.Tracer.Info("[{0}] Setup accepted ({1}: {2})", Tag, command, reply?.Trim());
                    else
                        Libs.Trace.Tracer.Info("[{0}] Setup reported a problem - {1} answered '{2}'{3}. Readings are taken anyway; " +
                                               "check the channel list and the sensor type in the settings.",
                            Tag, command, reply?.Trim(), res != null && res.Expired ? " (no reply in time)" : "");
                }
                SendSetup(commands, index + 1, generation);
            });
        }

        #endregion

        #region polling

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    if (_scan.Count == 0 || _function == Daq9600Function.Unsupported)
                        return CommonBL.SingleState.StepWorkResponses.StateFinished;

                    var generation = Volatile.Read(ref _generation);
                    Libs.Trace.Tracer.Info("[{0}] Starting polling loop #{1}: {2} channel(s) every {3} s", Tag, generation, _scan.Count, Interval().TotalSeconds);
                    if (HW_Device.RestartWatchdogClockForReconfiguration(DateTime.UtcNow))
                        Libs.Trace.Tracer.Info("[{0}] Setup finished; the data watchdog counts from here", Tag);
                    Poll(generation);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private TimeSpan Interval()
        {
            var seconds = settings.Daq9600.Interval;
            var interval = TimeSpan.FromSeconds(seconds > 0 ? seconds : 1);
            return interval < MinimumInterval ? MinimumInterval : interval;
        }

        private void Poll(int generation)
        {
            if (Volatile.Read(ref _generation) != generation) return;
            if (HW_Device == null || !HW_Device.IsConnected) return;

            var started = DateTime.UtcNow;
            var scan = _scan;
            var request = new LogsRequest(LogsRequest.LogCommands.GetLogs) { Packet = new HardwarePacket(Daq9600Readings.ReadCommand, true) };
            HW_Device.GetLogs(request, response =>
            {
                try
                {
                    if (Volatile.Read(ref _generation) != generation) return;
                    if (response != null && response.Result &&
                        Daq9600Readings.TryParseReadings(response.RawText, scan.Count, out var values))
                    {
                        _consecutiveFailures = 0;
                        Broadcast(scan, values);
                    }
                    else
                    {
                        _consecutiveFailures++;
                        // once, then every 10th: a dead link would otherwise write a line per interval for hours
                        if (_consecutiveFailures == 1 || _consecutiveFailures % 10 == 0)
                            Libs.Trace.Tracer.Info("[{0}] READ? gave no usable reply ({1} in a row): '{2}'{3}", Tag, _consecutiveFailures,
                                response?.RawText?.Trim(), response != null && response.Expired ? " (no reply in time)" : "");
                    }
                }
                finally
                {
                    // the next sweep starts one interval after this one started, not after it ended
                    var wait = Interval() - (DateTime.UtcNow - started);
                    if (wait < TimeSpan.Zero) wait = TimeSpan.Zero;
                    System.Threading.Tasks.Task.Delay(wait).ContinueWith(_ => Poll(generation));
                }
            });
        }

        /// <summary>One sweep to the clients, channel by channel (see the class remarks).</summary>
        private void Broadcast(List<int> scan, List<double> values)
        {
            var family = settings.Daq9600;
            var sensors = family.ChannelMasters ?? ChannelMasterMap.Empty;
            var channels = new List<int>();
            var sent = new List<double>();
            var heldBack = new Dictionary<int, string>();

            for (int i = 0; i < scan.Count; i++)
            {
                var channel = Daq9600Readings.ToAppChannel(scan[i]);
                var raw = values[i];

                if (Daq9600Readings.IsOverload(raw))
                {
                    _disconnects.Disconnected(channel);
                    continue;
                }
                _disconnects.Restored(channel);

                if (_function == Daq9600Function.VoltageDc)
                {
                    channels.Add(channel);
                    sent.Add(raw);
                    continue;
                }

                var sensor = ChannelCertificates.SensorFor(channel, sensors, family.Masters);
                Tuple<double, ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository.ResultStatus> result;
                if (_function == Daq9600Function.Thermocouple)
                {
                    if (!_certificates.Ensure(sensor)) { heldBack[channel] = sensor; continue; }
                    result = HC.CalcDeviationForTemperature(raw, sensor);
                }
                else
                {
                    // PT-100: ohms to degC with this sensor's own coefficients (as Agilent34401aBL does for its master)
                    if (sensor == null) { heldBack[channel] = null; continue; }
                    result = HC.CalcConversionUnits(raw, HydraCalculations.ConversionUnits.Ohm, HydraCalculations.ConversionUnits.Celsius, sensor);
                }

                if (result.Item2 == ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository.ResultStatus.WrongValue)
                {
                    heldBack[channel] = sensor;
                    continue;
                }

                Libs.Trace.Tracer.Info("[{0} Correction] CH{1} ({2}) | Raw={3:F4} | Corrected={4:F4} | Status={5} | Sensor={6}",
                    Tag, channel, scan[i], raw, result.Item1, result.Item2, sensor);
                channels.Add(channel);
                sent.Add(result.Item1);
            }

            _certificates.ReportHeldBack(heldBack);

            Libs.Trace.Tracer.Info("[{0}] Broadcasting {1} channel(s): [{2}] values: [{3}]", Tag, channels.Count,
                string.Join(",", channels), string.Join(",", sent.Select(v => v.ToString(CultureInfo.InvariantCulture))));
            HW_Device.BroadcastAllMeasurements(channels, sent);
        }

        #endregion
    }
}
