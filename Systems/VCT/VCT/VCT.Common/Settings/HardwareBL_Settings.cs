using Newtonsoft.Json;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.IO;

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
