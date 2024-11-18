using Newtonsoft.Json;
using System.IO;

namespace Maba.VCT.CommServer.BL.HydraDevices.Settings
{
    public class HydraBL_Settings
    {
        #region Constant

        public const string DEFAULT_SETTINGS_FOLDER = "Settings";
        public const string DEFAULT_FILE_NAME = "HydraBL_Settings.json";

        #endregion

        #region Properties

        public string GeneralDBName { get { return "KyulanSyncDB"; } }
        public string PriorityDBName { get { return "Priority"; } }
        #endregion

        #region Ctor

        public HydraBL_Settings()
        {
            //this.OfflineDevice = new HydraBL_DeviceType();
            //this.OnlineDevice = new HydraBL_DeviceType();
        }

        #endregion

        #region private methods
        private void Save(string fullPath, HydraBL_Settings obj)
        {
            try
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
            catch
            {
            }
        }

        #endregion

        #region public methods

        public void Save()
        {
            var fullPath = GetSettingsFullPath();

            Save(fullPath, this);

            Save(Path.ChangeExtension(fullPath, "default.json"), CreateDefaultSettings());

        }

        public static HydraBL_Settings CreateDefaultSettings()
        {
            var defaultSettings = new HydraBL_Settings()
            {
                //OfflineDevice = new HydraBL_DeviceType()
                //{
                //    OnlineDevice = false,
                //    ReadIO_Interval = TimeSpan.FromSeconds(0),
                //    IrrigationValues_Interval = TimeSpan.FromSeconds(0),
                //    CNFSyncInterval = TimeSpan.FromSeconds(0),
                //    GetLoHydra2nterval = TimeSpan.FromSeconds(0)
                //},
                //OnlineDevice = new HydraBL_DeviceType()
                //{
                //    OnlineDevice = true,
                //    ReadIO_Interval = TimeSpan.FromMinutes(5),
                //    IrrigationValues_Interval = TimeSpan.FromMinutes(1),
                //    CNFSyncInterval = TimeSpan.FromMinutes(30),
                //    GetLoHydra2nterval = TimeSpan.FromHours(1),
                //    ClockSyncInterval = TimeSpan.FromMinutes(30),
                //    GetDeviceType_Interval = TimeSpan.FromHours(1)
                //},
            };

            return defaultSettings;
        }

        #endregion

        #region static

        public static string GetSettingFolder()
        {
            var folderName = Path.Combine(
                     Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                  DEFAULT_SETTINGS_FOLDER);
            Directory.CreateDirectory(folderName);
            return folderName;
        }

        public static string GetSettingsFullPath()
        {
            return Path.Combine(GetSettingFolder(), DEFAULT_FILE_NAME);
        }

        public static HydraBL_Settings Read(bool CreateWhenMissing = true)
        {
            HydraBL_Settings _settings = null;
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
                                _settings = jSer.Deserialize(jReader, typeof(HydraBL_Settings)) as HydraBL_Settings;
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
