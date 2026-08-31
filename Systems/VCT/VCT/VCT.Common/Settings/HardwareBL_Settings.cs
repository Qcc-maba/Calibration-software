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

                    using (var st = new FileStream(fullPath, FileMode.OpenOrCreate, FileAccess.Write))
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
                        SensType = SensorType.SensorTypes.None,
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
                }
            };

            return defaultSettings;
        }

        #endregion

        #region WebSocket-driven config (MBA-485)

        /// <summary>All per-family buckets paired with a display name, for routing WS config.</summary>
        private IEnumerable<KeyValuePair<string, HardwareBL_DeviceType>> Families()
        {
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Hydra2", Hydra2type);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Hydra3", Hydra3type);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Agilent", Agilent);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Additel", Additel);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Optidew", Optidew);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("TTI22", TTI22);
            yield return new KeyValuePair<string, HardwareBL_DeviceType>("Instek", Instek);
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
        /// </summary>
        private static List<int> ParseChannels(string spec)
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
            if (target == null) return null;

            var applied = new List<string>();

            var r = ParseRate(rate);
            if (r.HasValue) { target.MeasurementRate = r.Value; applied.Add("rate=" + r.Value); }

            if (int.TryParse((interval ?? "").Trim(), out var iv) && iv > 0) { target.Interval = iv; applied.Add("interval=" + iv); }

            var chans = ParseChannels(channelsCsv);
            if (chans.Count > 0) { target.Channels = chans; applied.Add("channels=[" + string.Join(",", chans) + "]"); }

            if (applied.Count == 0) return null;
            return string.Format("{0} (master {1}): {2}", targetName, id, string.Join(", ", applied));
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
