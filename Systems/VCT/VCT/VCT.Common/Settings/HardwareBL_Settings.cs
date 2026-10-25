using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydraDevices.Settings
{
    public class HardwareBL_Settings
    {
        #region Constant

        public const string DEFAULT_SETTINGS_FOLDER = "Settings";
        public const string DEFAULT_FILE_NAME = "HydraBL_Settings.json";
        #endregion

        #region Device Members
        public static HardwareBL_Settings _settings = null;

        public HardwareBL_DeviceType Hydra3type { get; private set; }
        public HardwareBL_DeviceType Hydra2type { get; private set; }
        public HardwareBL_DeviceType Agilent { get; private set; }
        public HardwareBL_DeviceType Additel { get; private set; }
        public HardwareBL_DeviceType Optidew { get; private set; }
        public HardwareBL_DeviceType TTI22 { get; private set; }
        public HardwareBL_DeviceType Instek { get; private set; }
        /// <summary>Keysight EDUX1002A oscilloscope (1000 X-Series).</summary>
        public HardwareBL_DeviceType Edux1002a { get; private set; }
        /// <summary>Pendulum CNT-90 timer/counter/analyzer.</summary>
        public HardwareBL_DeviceType Cnt90 { get; private set; }
        /// <summary>Siglent SDG6052X arbitrary waveform generator (a source, not a logger).</summary>
        public HardwareBL_DeviceType Sdg6052x { get; private set; }
        /// <summary>PRODIGIT 3111 DC electronic load.</summary>
        public HardwareBL_DeviceType Prodigit3111 { get; private set; }
        /// <summary>HP 53181A frequency counter.</summary>
        public HardwareBL_DeviceType Hp53181a { get; private set; }
        /// <summary>Fluke 5522A multi-product calibrator (a source, not a logger).</summary>
        public HardwareBL_DeviceType Fluke5522a { get; private set; }
        /// <summary>Fluke 5322A electrical tester calibrator (a source, not a logger).</summary>
        public HardwareBL_DeviceType Fluke5322a { get; private set; }
        /// <summary>Meatest M-142 multifunction calibrator - a source that also has an internal meter.</summary>
        public HardwareBL_DeviceType MeatestM142 { get; private set; }

        #endregion

        #region Ctor

        public HardwareBL_Settings()
        {
            Hydra3type = new HardwareBL_DeviceType();
            Hydra2type = new HardwareBL_DeviceType();
            Agilent = new HardwareBL_DeviceType();
            Additel = new HardwareBL_DeviceType();
            Optidew = new HardwareBL_DeviceType();
            TTI22 = new HardwareBL_DeviceType();
            Instek = new HardwareBL_DeviceType();
            Edux1002a = new HardwareBL_DeviceType();
            Cnt90 = new HardwareBL_DeviceType();
            Sdg6052x = new HardwareBL_DeviceType();
            Prodigit3111 = new HardwareBL_DeviceType();
            Hp53181a = new HardwareBL_DeviceType();
            Fluke5522a = new HardwareBL_DeviceType();
            Fluke5322a = new HardwareBL_DeviceType();
            MeatestM142 = new HardwareBL_DeviceType();
        }

        #endregion

        #region private methods
        [ExcludeFromCodeCoverage]
        private void Save(string fullPath, HardwareBL_Settings obj)
        {
            try
            {
                lock (Hydra3type)
                {
                    var Jset = new JsonSerializerSettings()
                    {
                        Formatting = Formatting.Indented
                    };

                    // FileMode.Create, not OpenOrCreate: OpenOrCreate does not truncate, so saving a settings
                    // file shorter than the one on disk left the tail of the old content behind and
                    // produced a file that is valid JSON followed by garbage.
                    using (var st = new FileStream(fullPath, FileMode.Create, FileAccess.Write))
                    {
                        using (var txtWriter = new StreamWriter(st))
                        {
                            using (var jWrite = new JsonTextWriter(txtWriter))
                            {
                                var jSer = JsonSerializer.Create(Jset);
                                jSer.Serialize(jWrite, obj);
                            }
                        }
                    }
                }
            }
            catch
            {
            }
        }

        #endregion

        #region public methods

        [ExcludeFromCodeCoverage]
        public void Save()
        {
            var fullPath = GetSettingsFullPath();

            Save(fullPath, this);

            Save(Path.ChangeExtension(fullPath, "default.json"), CreateDefaultSettings());

        }

        public static HardwareBL_Settings CreateDefaultSettings()
        {
            var defaultSettings = new HardwareBL_Settings()
            {
                Hydra3type = new HardwareBL_DeviceType()
                {
                    Channels = new List<int>() { 101, 102 },
                    Interval = 30,
                    MeasurementRate = HardwareBL_DeviceType.MeasurementRates.FAST,
                    MaxNumOfChannels = 200,
                    Sensor = new SensorType
                    {
                        ThermocoupleType = SensorType.ThermocoupleTypes.K,
                        MeasureType = SensorType.MeasureTypes.TEMP,
                    },
                    Masters = new List<string>() { "21-449" }
                },
                Hydra2type = new HardwareBL_DeviceType()
                {
                    Channels = new List<int>() { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
                    Interval = 30,
                    MeasurementRate = HardwareBL_DeviceType.MeasurementRates.SLOW,
                    MaxNumOfChannels = 200,
                    Sensor = new SensorType
                    {
                        ThermocoupleType = SensorType.ThermocoupleTypes.K,
                        MeasureType = SensorType.MeasureTypes.TEMP,
                    },
                    Masters = new List<string>() { "21-449" }
                },
                Agilent = new HardwareBL_DeviceType()
                {
                    Channels = new List<int> { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>() { "21-114" },
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.FRTD,
                        MeasureType = SensorType.MeasureTypes.VDC,
                    }
                },
                Additel = new HardwareBL_DeviceType()
                {
                    Channels = new List<int> { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>() { "21-702" },
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.FRTD,
                        MeasureType = SensorType.MeasureTypes.Resistance,
                    }
                },
                Optidew = new HardwareBL_DeviceType()
                {
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>() { "21-711" },
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.Dew,
                    }
                },
                TTI22 = new HardwareBL_DeviceType()
                {
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>() { "21-422" },
                    Sensor = new SensorType
                    {
                        // Reads the resistance of a 4-wire PRT, and is used for temperature as well as
                        // ohms. Naming the probe keeps it reporting Celsius through the general rule
                        // rather than a per-device exception. ProcessResults switches on MeasureType
                        // only, so this changes no measurement behaviour.
                        SensType = SensorType.SensorTypes.FRTD,
                        MeasureType = SensorType.MeasureTypes.Resistance,
                    }
                },
                Instek = new HardwareBL_DeviceType()
                {
                    Channels = new List<int>() { 101, 102 },
                    Interval = 30,
                    MeasurementRate = HardwareBL_DeviceType.MeasurementRates.SLOW,
                    MaxNumOfChannels = 50,
                    Masters = new List<string>() { "21-999" },
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.TCouple,
                        ThermocoupleType = SensorType.ThermocoupleTypes.K,
                        MeasureType = SensorType.MeasureTypes.TEMP,
                    },
                },
                Edux1002a = new HardwareBL_DeviceType()
                {
                    // The EDUX1002A has exactly two analog channels; both are acquired by default.
                    Channels = new List<int>() { 1, 2 },
                    MaxNumOfChannels = 2,
                    // Left empty on purpose: the scope reads a signal directly, it applies no master
                    // correction curve. Fill in the real MabaID only to let the app's
                    // LoggerConfiguration message (ApplyWebSocketConfig) reach this family.
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.VoltagePP,
                    },
                },
                Cnt90 = new HardwareBL_DeviceType()
                {
                    // Measurement inputs A and B. (@3) is the optional prescaler and (@4) the rear
                    // arming input, neither of which this BL acquires.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 2,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.Frequency,
                    },
                },
                Sdg6052x = new HardwareBL_DeviceType()
                {
                    // A source: what it "reports" is the setpoint it is configured to produce, which
                    // is what a calibration compares the counter's reading against.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 2,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.Frequency,
                    },
                },
                Prodigit3111 = new HardwareBL_DeviceType()
                {
                    // Single-channel load. It measures the voltage across, and current through, its
                    // own input; MeasureType picks which of the three the BL broadcasts.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.VoltageDC,
                    },
                },
                Hp53181a = new HardwareBL_DeviceType()
                {
                    // Channel 1 is the 225 MHz input; channel 2 is the optional high-frequency one.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 2,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.Frequency,
                    },
                },
                Fluke5522a = new HardwareBL_DeviceType()
                {
                    // A source: what it "reports" is the setpoint it is configured to produce, which
                    // is what a calibration compares a meter's reading against.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.VoltageDC,
                    },
                },
                Fluke5322a = new HardwareBL_DeviceType()
                {
                    // A source: what it "reports" is the setpoint it is configured to produce.
                    // Resistance rather than volts, because ground bond and the two resistance
                    // simulations are what an electrical-tester calibrator spends nearly all its
                    // time in - the voltage function is one mode out of twenty-odd.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.Resistance,
                    },
                },
                MeatestM142 = new HardwareBL_DeviceType()
                {
                    // Both a source and a meter. Unlike the other calibrators here it can report a
                    // value it actually measured (MEAS?), and falls back to its own setpoint only
                    // when the internal multimeter is switched off.
                    Channels = new List<int>() { 1 },
                    MaxNumOfChannels = 1,
                    Masters = new List<string>(),
                    Sensor = new SensorType
                    {
                        SensType = SensorType.SensorTypes.None,
                        MeasureType = SensorType.MeasureTypes.VoltageDC,
                    },
                }
            };

            return defaultSettings;
        }

        #endregion


        #region default measurement units

        // The unit that goes out on a LoggerData broadcast when the web app has NOT associated a
        // sensor. An association always wins - these are only the server's own defaults, and they
        // used to be a flat "Celsius" for every instrument, which is plainly wrong for one that
        // measures electricity (a scope reporting volts as Celsius).

        public const string Units_Temperature = "Celsius";
        public const string Units_Voltage = "Volt";
        public const string Units_Resistance = "Ohm";
        public const string Units_Frequency = "Hertz";
        public const string Units_Humidity = "Percent";
        public const string Units_Current = "Ampere";
        public const string Units_Power = "Watt";

        /// <summary>
        /// The unit a sensor configuration produces.
        /// <para>
        /// This must agree with <c>HydraCalculations.ProcessResults</c>, which is what actually turns a
        /// reading into a broadcast value - the unit is a property of the value that comes OUT, not of
        /// the quantity the instrument probes. Two consequences that are easy to get backwards:
        /// </para>
        /// <list type="bullet">
        /// <item><c>VDC</c> does not mean volts here. ProcessResults runs it through
        /// CalcResistanceToTemperatureITS90 and emits Celsius; it is the legacy spelling for
        /// "resistance read as a temperature" and is how the 34401A is configured. An instrument that
        /// genuinely reports DC volts uses <c>VoltageDC</c>.</item>
        /// <item>An RTD / 4-wire RTD / thermocouple sensor reports a temperature whatever the
        /// MeasureType says, because the BL converts before broadcasting (see
        /// Agilent34401aReadings.RequiresTemperatureConversion).</item>
        /// </list>
        /// </summary>
        public static string UnitsForSensor(SensorType sensor)
        {
            if (sensor == null)
                return Units_Temperature;

            // A temperature probe yields a temperature no matter which MeasureType names it.
            if (sensor.SensType == SensorType.SensorTypes.RTD ||
                sensor.SensType == SensorType.SensorTypes.FRTD ||
                sensor.SensType == SensorType.SensorTypes.TCouple)
                return Units_Temperature;

            switch (sensor.MeasureType)
            {
                case SensorType.MeasureTypes.VoltageDC:
                case SensorType.MeasureTypes.VoltagePP:
                case SensorType.MeasureTypes.VoltageRMS:
                    return Units_Voltage;
                case SensorType.MeasureTypes.Frequency:
                    return Units_Frequency;
                case SensorType.MeasureTypes.Current:
                    return Units_Current;
                case SensorType.MeasureTypes.Power:
                    return Units_Power;
                case SensorType.MeasureTypes.Resistance:
                    return Units_Resistance;
                case SensorType.MeasureTypes.Humidity:
                    // ProcessResults reports temperature as the primary value and humidity as the
                    // second one; the LoggerData broadcast carries the primary.
                    return Units_Temperature;
                case SensorType.MeasureTypes.VDC:   // resistance converted to temperature (ITS-90)
                case SensorType.MeasureTypes.TEMP:
                case SensorType.MeasureTypes.Dew:   // dew point is a temperature
                case SensorType.MeasureTypes.None:
                default:
                    return Units_Temperature;
            }
        }

        /// <summary>
        /// Finds the family bucket that configures the device with this identification SN. The tokens
        /// are the same ones the BL cores claim devices by (see each BLCore.DeviceIdToken) - keep the
        /// two lists in step when adding an instrument.
        /// </summary>
        public HardwareBL_DeviceType ResolveFamilyBySN(string sn)
        {
            if (string.IsNullOrEmpty(sn))
                return null;

            if (sn.IndexOf("2625", StringComparison.OrdinalIgnoreCase) >= 0) return Hydra2type;
            if (sn.IndexOf("2638", StringComparison.OrdinalIgnoreCase) >= 0) return Hydra3type;
            if (sn.IndexOf("53181A", StringComparison.OrdinalIgnoreCase) >= 0) return Hp53181a;
            if (sn.IndexOf("5522A", StringComparison.OrdinalIgnoreCase) >= 0) return Fluke5522a;
            if (sn.IndexOf("5322A", StringComparison.OrdinalIgnoreCase) >= 0) return Fluke5322a;
            if (sn.IndexOf("M-142", StringComparison.OrdinalIgnoreCase) >= 0) return MeatestM142;
            if (sn.IndexOf("HEWLETT", StringComparison.OrdinalIgnoreCase) >= 0) return Agilent;
            if (sn.IndexOf("TAU", StringComparison.OrdinalIgnoreCase) >= 0) return Additel;
            if (sn.IndexOf("Optidew", StringComparison.OrdinalIgnoreCase) >= 0) return Optidew;
            if (sn.IndexOf("TTI", StringComparison.OrdinalIgnoreCase) >= 0) return TTI22;
            if (sn.IndexOf("Instek", StringComparison.OrdinalIgnoreCase) >= 0) return Instek;
            if (sn.IndexOf("EDUX1002A", StringComparison.OrdinalIgnoreCase) >= 0) return Edux1002a;
            if (sn.IndexOf("CNT-90", StringComparison.OrdinalIgnoreCase) >= 0) return Cnt90;
            if (sn.IndexOf("SDG6052X", StringComparison.OrdinalIgnoreCase) >= 0) return Sdg6052x;
            if (sn.IndexOf("PRODIGIT", StringComparison.OrdinalIgnoreCase) >= 0) return Prodigit3111;

            return null;
        }

        /// <summary>
        /// Default units for the device with this identification SN, used only when the app has sent
        /// no sensor association.
        /// </summary>
        public string DefaultUnitsForDeviceSN(string sn)
        {
            // The Datron/Wavetek 9100 is a source, not a logger, so it has no family bucket here - but
            // it is unambiguously an electrical instrument.
            if (!string.IsNullOrEmpty(sn) && sn.IndexOf("Datron9100", StringComparison.OrdinalIgnoreCase) >= 0)
                return Units_Voltage;

            var family = ResolveFamilyBySN(sn);
            return family == null ? Units_Temperature : UnitsForSensor(family.Sensor);
        }

        #endregion

        #region WebSocket-driven config (MBA-485)

        /// <summary>All per-family buckets paired with a display name, for routing WS config.</summary>
        #region live families

        /*  Which settings family a connected instrument is actually being driven by. A BL registers
            itself when it starts, and that is the only thing in the process that knows the answer -
            the settings file describes every family we support, not the one plugged in today.  */
        private static readonly HashSet<string> _activeFamilies =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private static readonly object _activeFamiliesLock = new object();

        /// <summary>Called by a device BL as it starts, and again on every re-initialisation. Idempotent.</summary>
        public static void RegisterActiveFamily(string familyName)
        {
            if (string.IsNullOrWhiteSpace(familyName)) return;
            lock (_activeFamiliesLock) { _activeFamilies.Add(familyName.Trim()); }
        }

        /// <summary>Called when a device's BL stops driving it, so a family that is gone stops being a candidate.</summary>
        public static void UnregisterActiveFamily(string familyName)
        {
            if (string.IsNullOrWhiteSpace(familyName)) return;
            lock (_activeFamiliesLock) { _activeFamilies.Remove(familyName.Trim()); }
        }

        /// <summary>A snapshot, so callers never enumerate the set while a device connects.</summary>
        public static List<string> ActiveFamilies()
        {
            lock (_activeFamiliesLock) { return _activeFamilies.ToList(); }
        }

        #endregion

        private IEnumerable<KeyValuePair<string, HardwareBL_DeviceType>> Families()
        {
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Hydra2", Hydra2type);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Hydra3", Hydra3type);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Agilent", Agilent);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Additel", Additel);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Optidew", Optidew);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("TTI22", TTI22);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Instek", Instek);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Edux1002a", Edux1002a);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Cnt90", Cnt90);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Sdg6052x", Sdg6052x);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Prodigit3111", Prodigit3111);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Hp53181a", Hp53181a);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Fluke5522a", Fluke5522a);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Fluke5322a", Fluke5322a);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("MeatestM142", MeatestM142);
        }

        /// <summary>Maps the app's Rate free-text ('איטי'/'מהיר', 'slow'/'fast') to the BL rate enum.</summary>
        private static HardwareBL_DeviceType.MeasurementRates? ParseRate(string rate)
        {
            if (string.IsNullOrWhiteSpace(rate)) return null;
            var r = rate.Trim();
            if (r.IndexOf("מהיר", StringComparison.Ordinal) >= 0 || r.IndexOf("fast", StringComparison.OrdinalIgnoreCase) >= 0)
                return HardwareBL_DeviceType.MeasurementRates.FAST;
            if (r.IndexOf("איטי", StringComparison.Ordinal) >= 0 || r.IndexOf("slow", StringComparison.OrdinalIgnoreCase) >= 0)
                return HardwareBL_DeviceType.MeasurementRates.SLOW;
            return null;
        }

        /// <summary>
        /// Parses a channel list into a distinct, ordered set. Accepts the web app's format
        /// (space-separated with ranges, e.g. "0-10 11 20-23" or "1-5") as well as comma-separated
        /// (e.g. the DB ChannelList "0,1,2"). Ranges "a-b" are expanded inclusively.
        /// Public because the WebSocket host labels readings per channel from the same BatchChannels
        /// text (MBA-967), and two parsers of one field would sooner or later disagree on a channel.
        /// </summary>
        public static List<int> ParseChannels(string spec)
        {
            var set = new SortedSet<int>();
            if (!string.IsNullOrWhiteSpace(spec))
            {
                var tokens = spec.Replace(',', ' ').Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var raw in tokens)
                {
                    var token = raw.Trim();
                    var dash = token.IndexOf('-');
                    if (dash > 0 && dash < token.Length - 1)
                    {
                        if (int.TryParse(token.Substring(0, dash).Trim(), out var lo)
                            && int.TryParse(token.Substring(dash + 1).Trim(), out var hi)
                            && hi >= lo && hi - lo < 10000)
                        {
                            for (var ch = lo; ch <= hi; ch++) set.Add(ch);
                        }
                    }
                    else if (int.TryParse(token, out var single))
                    {
                        set.Add(single);
                    }
                }
            }
            return set.ToList();
        }

        /// <summary>MBA-967: the distinct, ascending union of two channel lists.</summary>
        private static List<int> UnionChannels(IEnumerable<int> current, IEnumerable<int> added)
        {
            var set = new SortedSet<int>(current ?? Enumerable.Empty<int>());
            set.UnionWith(added ?? Enumerable.Empty<int>());
            return set.ToList();
        }

        /// <summary>
        /// MBA-485: applies a logger configuration pushed by the web app over WebSocket
        /// (CMD:"LoggerConfiguration") to the in-memory per-family settings, so the BL drives the
        /// device by what the logged-in operator configured — no DB and no restart. Routes to the
        /// family whose <see cref="HardwareBL_DeviceType.Masters"/> includes <paramref name="loggerId"/>.
        /// Returns a short summary of what changed, or null if no family matched / nothing applied.
        /// Mutates in place (the BL holds the same instance), so it takes effect on the next scan setup.
        /// </summary>
        public string ApplyWebSocketConfig(string loggerId, string rate, string interval, string channelsCsv)
        {
            return ApplyWebSocketConfig(loggerId, rate, interval, channelsCsv, addChannels: false);
        }

        /// <summary>
        /// MBA-967: applies the channels of one sensor (CMD:"SensorsAssociation") by ADDING them to the
        /// logger's channel list instead of replacing it. One Confirm sends LoggerConfiguration with
        /// every channel of the logger and then one SensorsAssociation per sensor, each carrying only
        /// that sensor's channels. When each of those replaced the list, sensor A on 1-3 and sensor B
        /// on 4-6 left the logger scanning 4-6 only - A's channels were never measured. The list is
        /// set by LoggerConfiguration; a sensor can only add to it. A sensor whose channels are all
        /// present already changes nothing and returns null, so it never triggers a re-init.
        /// Held (unidentified-logger) configurations get the same union.
        /// </summary>
        public string AddWebSocketSensorChannels(string loggerId, string channelsCsv)
        {
            return ApplyWebSocketConfig(loggerId, null, null, channelsCsv, addChannels: true);
        }

        private string ApplyWebSocketConfig(string loggerId, string rate, string interval, string channelsCsv, bool addChannels)
        {
            if (string.IsNullOrWhiteSpace(loggerId)) return null;
            var id = loggerId.Trim();

            HardwareBL_DeviceType target = null;
            string targetName = null;
            foreach (var fam in Families())
            {
                if (fam.Value?.Masters != null &&
                    fam.Value.Masters.Any(m => string.Equals((m ?? "").Trim(), id, StringComparison.OrdinalIgnoreCase)))
                {
                    target = fam.Value;
                    targetName = fam.Key;
                    break;
                }
            }

            /*  The operator's screen is authoritative about which logger is on the bench, and the
                app sends that logger's MABA id. Requiring the id to appear in a Masters list written
                into HydraBL_Settings.json by hand meant that on every station whose logger was not
                the one the file happened to name, the whole message was dropped and the device kept
                the file's default of twenty channels - which is also what made start-up take about a
                minute, at two seconds per channel (MBA-962).

                So when the id is unknown, fall back to the family a live device is actually driving.
                Only when exactly one is live: with two loggers connected there is no honest way to
                decide which one the message is about, and guessing would configure the wrong
                instrument. Masters is deliberately NOT extended here - it selects correction curves,
                and a channel list must not quietly change which corrections a reading gets.  */
            if (target == null)
            {
                var live = ActiveFamilies();
                if (live.Count == 1)
                {
                    foreach (var fam in Families())
                    {
                        if (string.Equals(fam.Key, live[0], StringComparison.OrdinalIgnoreCase))
                        {
                            target = fam.Value;
                            targetName = fam.Key + " (matched by the live device, not by Masters)";
                            break;
                        }
                    }
                }
            }

            if (target == null)
            {
                HoldPendingWebSocketConfig(id, rate, interval, channelsCsv, DateTime.UtcNow, addChannels);
                return null;
            }

            // A routed message supersedes anything held for this logger from before it was identified.
            ClearPendingWebSocketConfig(id);

            return ApplyTo(target, targetName, id, rate, interval, channelsCsv, addChannels);
        }

        private static string ApplyTo(HardwareBL_DeviceType target, string targetName, string id,
                                      string rate, string interval, string channelsCsv, bool addChannels = false)
        {
            /*  MBA-974: only report a field as applied when it actually differs from what target
                already holds. Before this, resending the same rate/interval/channels (e.g. the app
                re-sending SensorsAssociation because an unrelated field like units changed) always
                reported "applied", even though nothing was new - which would make a live-hardware
                reinitialization triggered on "applied != null" fire on every no-op resend instead of
                only on a genuine change. */
            var applied = new List<string>();

            var r = ParseRate(rate);
            if (r.HasValue && target.MeasurementRate != r.Value) { target.MeasurementRate = r.Value; applied.Add("rate=" + r.Value); }

            if (int.TryParse((interval ?? "").Trim(), out var iv) && iv > 0 && target.Interval != iv) { target.Interval = iv; applied.Add("interval=" + iv); }

            var chans = ParseChannels(channelsCsv);
            // MBA-967: a sensor's channels join the list (see AddWebSocketSensorChannels). Checked as
            // containment first, so channels already present change nothing even when the current
            // list is not in ascending order (a hand-written settings file need not be).
            if (addChannels && chans.Count > 0)
            {
                var current = target.Channels ?? new List<int>();
                chans = chans.All(current.Contains) ? new List<int>() : UnionChannels(current, chans);
            }
            if (chans.Count > 0 && !chans.SequenceEqual(target.Channels ?? new List<int>()))
            {
                target.Channels = chans;
                applied.Add("channels=[" + string.Join(",", chans) + "]");
            }

            if (applied.Count == 0) return null;
            return string.Format("{0} (master {1}): {2}", targetName, id, string.Join(", ", applied));
        }

        #region configuration that arrives before the logger is identified (MBA-967)

        /*  On the operator's first Confirm the app sends LoggerConfiguration, SensorsAssociation and
            Status:Start together, in that order. Identification waits for the Start, so when the
            channel list arrives no BL is live and the logger's MABA id is normally not in any
            Masters list: nothing can be routed, and the list used to be dropped ("no matching
            family ... kept current settings"). The logger was then set up from the settings file -
            twenty channels on Nofar's station - and only the second Confirm, arriving while it was
            live, applied the operator's channels. Measured 2026-09-30: channels 1,3,5,6,7 selected,
            FUNC sent for 1,11,15,5,2,3.

            So an unroutable message is held, and the BL applies it as it registers - before its
            channel-setup state runs - so the first init already uses the operator's channels. It is
            held per logger id (a later message for the same logger merges into it), and it expires:
            a list typed long ago must not configure an instrument plugged in much later.

            The BL cannot tell which held configuration is its own. Identification yields the
            logger's serial number ("FLUKE,2625A,..."), and nothing on the server maps that to the
            MABA id the app sends (21-337). So a configuration is applied only when it is the only one
            held. With two - the app configured loggers A and B before either was identified - applying
            either could set up A with B's channels, rate and interval; none is applied, both are
            dropped, and the second Confirm, arriving while the logger is live, configures it by the
            normal path.  */

        private sealed class PendingWebSocketConfig
        {
            public string LoggerId;
            public string Rate;
            public string Interval;
            public string Channels;
            public DateTime ReceivedUtc;
        }

        /// <summary>Held configurations by logger id. Guarded by <see cref="_activeFamiliesLock"/>.</summary>
        private static readonly Dictionary<string, PendingWebSocketConfig> _pendingConfigs =
            new Dictionary<string, PendingWebSocketConfig>(StringComparer.OrdinalIgnoreCase);

        /// <summary>How long a held configuration waits for a logger to be identified.</summary>
        public static readonly TimeSpan PendingConfigLifetime = TimeSpan.FromMinutes(5);

        /// <param name="addChannels">
        /// MBA-967: true for a SensorsAssociation - its channels join the held list rather than
        /// replace it, for the same reason as on a live logger (sensor A on 1-3, then B on 4-6, must
        /// leave 1-6 held, not 4-6).
        /// </param>
        internal static void HoldPendingWebSocketConfig(string loggerId, string rate, string interval, string channelsCsv, DateTime nowUtc,
                                                        bool addChannels = false)
        {
            lock (_activeFamiliesLock)
            {
                if (!_pendingConfigs.TryGetValue(loggerId, out var p) || nowUtc - p.ReceivedUtc > PendingConfigLifetime)
                {
                    p = new PendingWebSocketConfig { LoggerId = loggerId };
                }

                // Merge: SensorsAssociation carries channels only, LoggerConfiguration all three.
                if (!string.IsNullOrWhiteSpace(rate)) p.Rate = rate;
                if (!string.IsNullOrWhiteSpace(interval)) p.Interval = interval;
                if (!string.IsNullOrWhiteSpace(channelsCsv))
                {
                    p.Channels = addChannels && !string.IsNullOrWhiteSpace(p.Channels)
                        ? string.Join(",", UnionChannels(ParseChannels(p.Channels), ParseChannels(channelsCsv)))
                        : channelsCsv;
                }
                p.ReceivedUtc = nowUtc;
                _pendingConfigs[loggerId] = p;
            }
        }

        /// <summary>Drops every held configuration.</summary>
        public static void ClearPendingWebSocketConfig()
        {
            lock (_activeFamiliesLock) { _pendingConfigs.Clear(); }
        }

        /// <summary>Drops the held configuration of one logger, when a message for it has been routed.</summary>
        private static void ClearPendingWebSocketConfig(string loggerId)
        {
            lock (_activeFamiliesLock) { _pendingConfigs.Remove(loggerId); }
        }

        /// <summary>True when a configuration for <paramref name="loggerId"/> is held. For the log line that says so.</summary>
        public static bool IsWebSocketConfigHeld(string loggerId)
        {
            if (string.IsNullOrWhiteSpace(loggerId)) return false;
            lock (_activeFamiliesLock) { return _pendingConfigs.ContainsKey(loggerId.Trim()); }
        }

        /// <summary>
        /// Called by a BL as it registers its family, before it sets the instrument up: applies and
        /// clears a configuration held because it arrived before any logger was identified. Returns a
        /// summary of what changed, or null when nothing was held, it expired, it changed nothing, or
        /// more than one logger's configuration was held.
        /// </summary>
        public string ApplyPendingWebSocketConfig(string familyName, DateTime nowUtc)
        {
            return ApplyPendingWebSocketConfig(familyName, nowUtc, out _);
        }

        /// <param name="familyName">The family of the BL that is registering.</param>
        /// <param name="nowUtc">Now, for the expiry.</param>
        /// <param name="ambiguousLoggerIds">
        /// When configurations for more than one logger were held, their ids, comma-separated - none
        /// was applied and all were dropped. Otherwise null.
        /// </param>
        public string ApplyPendingWebSocketConfig(string familyName, DateTime nowUtc, out string ambiguousLoggerIds)
        {
            ambiguousLoggerIds = null;
            List<PendingWebSocketConfig> live;
            lock (_activeFamiliesLock)
            {
                live = _pendingConfigs.Values.Where(c => nowUtc - c.ReceivedUtc <= PendingConfigLifetime).ToList();
                _pendingConfigs.Clear();
            }

            if (live.Count == 0) return null;
            if (live.Count > 1)
            {
                ambiguousLoggerIds = string.Join(",", live.Select(c => c.LoggerId).OrderBy(id => id, StringComparer.OrdinalIgnoreCase));
                return null;
            }

            var p = live[0];
            foreach (var fam in Families())
            {
                if (string.Equals(fam.Key, familyName, StringComparison.OrdinalIgnoreCase))
                {
                    return ApplyTo(fam.Value, fam.Key + " (held until the logger was identified)", p.LoggerId, p.Rate, p.Interval, p.Channels);
                }
            }
            return null;
        }

        #endregion

        /// <summary>
        /// MBA-974: resolves which settings family a LoggerID's config would apply to, without
        /// mutating anything - the exact same routing rule as <see cref="ApplyWebSocketConfig"/>
        /// (Masters match, else the single live family). Kept as a small, deliberately duplicated
        /// sibling rather than refactored out of that already-proven-correct method, so a live
        /// reconfiguration's hardware re-init target is resolved the same way the settings write was,
        /// without risking a change to the routing logic actually driving connected instruments today.
        /// </summary>
        public string ResolveLiveFamilyKey(string loggerId)
        {
            if (string.IsNullOrWhiteSpace(loggerId)) return null;
            var id = loggerId.Trim();

            foreach (var fam in Families())
            {
                if (fam.Value?.Masters != null &&
                    fam.Value.Masters.Any(m => string.Equals((m ?? "").Trim(), id, StringComparison.OrdinalIgnoreCase)))
                {
                    return fam.Key;
                }
            }

            var live = ActiveFamilies();
            return live.Count == 1 ? live[0] : null;
        }

        #endregion

        #region static

        [ExcludeFromCodeCoverage]
        public static string GetSettingFolder()
        {
            var folderName = Path.Combine(
                     Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                  DEFAULT_SETTINGS_FOLDER);
            Directory.CreateDirectory(folderName);
            return folderName;
        }

        [ExcludeFromCodeCoverage]
        public static string GetSettingsFullPath()
        {
            return Path.Combine(GetSettingFolder(), DEFAULT_FILE_NAME);
        }

        public static HardwareBL_Settings Read(bool CreateWhenMissing = true)
        {
            if (_settings != null)
            {
                return _settings;
            }
            var filenamePath = GetSettingsFullPath();
            try
            {
                if (File.Exists(filenamePath))
                {
                    var Jset = new JsonSerializerSettings()
                    {
                        Formatting = Formatting.Indented
                    };


                    using (var st = new FileStream(filenamePath, FileMode.OpenOrCreate, FileAccess.Read))
                    {
                        using (var txtReader = new StreamReader(st))
                        {
                            using (var jReader = new JsonTextReader(txtReader))
                            {
                                var jSer = JsonSerializer.Create(Jset);
                                _settings = jSer.Deserialize(jReader, typeof(HardwareBL_Settings)) as HardwareBL_Settings;
                            }
                        }
                    }
                }
            }
            catch
            {
            }

            _settings = _settings ?? CreateDefaultSettings();
            _settings.Save();

            return _settings;
        }

        #endregion
    }
}
