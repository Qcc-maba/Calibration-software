using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.Core.Settings
{
    public class ComServerSettings
    {
        #region Properties

        public const string DEFAULT_SETTINGS_FILE_NAME = "ComServerSettings.json";
        public const string DEFAULT_SETTINGS_FOLDER_NAME = "Settings";

        public Module[] Modules { get; set; }
        public Dictionary<string, string>[] IP2Scan { get; set; }

        #endregion

        #region private methods
        private void Save(string fullPath, ComServerSettings obj)
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

        #region Public static

        public static ComServerSettings CreateDefaultSettings()
        {
            var defaultSettings = new Core.Settings.ComServerSettings()
            {
                IP2Scan = new Dictionary<string, string>[]
              {
                      new Dictionary<string, string>()
                        { 
                           ["10.3.3.46"] = "21-431",
                           ["10.3.3.47"] = "21-473",
                           ["10.3.3.34"] = "21-474",
                           ["10.3.3.37"] = "21-527",
                           ["10.3.3.32"] = "21-534",
                           ["10.3.3.38"] = "21-549",
                           ["10.3.3.33"] = "21-596",
                           ["10.3.3.35"] = "21-597",
                           ["10.3.3.39"] = "21-649",
                           ["10.3.3.48"] = "21-651",
                           ["10.3.3.36"] = "31-65",
                           ["10.3.3.40"] = "21-999"
                        },
              }
            };
            return defaultSettings;
        }

        public static ComServerSettings Read()
        {
            var defaults = CreateDefaultSettings();

            ComServerSettings _settings = null;
            var filenamePath = GetSettingsFullPath();
            try
            {
                if (File.Exists(filenamePath))
                {
                    var Jset = new Newtonsoft.Json.JsonSerializerSettings()
                    {
                        Formatting = Newtonsoft.Json.Formatting.Indented
                    };
                    using (var st = new FileStream(filenamePath, FileMode.OpenOrCreate, FileAccess.Read))
                    {
                        using (var txtReader = new StreamReader(st))
                        {
                            using (var jReader = new Newtonsoft.Json.JsonTextReader(txtReader))
                            {
                                var jSer = Newtonsoft.Json.JsonSerializer.Create(Jset);
                                _settings = jSer.Deserialize(jReader, typeof(ComServerSettings)) as ComServerSettings;
                            }
                        }
                    }
                }
            }
            catch
            { }

            _settings = _settings ?? CreateDefaultSettings();

            _settings.Save();
            return _settings;
        }

        public static string GetSettingsFullPath()
        {
            var folder = Path.Combine(
                Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                DEFAULT_SETTINGS_FOLDER_NAME);

            Directory.CreateDirectory(folder);

            return Path.Combine(folder, DEFAULT_SETTINGS_FILE_NAME);
        }

        #endregion

        #region public Methods

        public void Save()
        {
            var fullPath = GetSettingsFullPath();

            Save(fullPath, this);

            Save(Path.ChangeExtension(fullPath, "default.json"), CreateDefaultSettings());
        }

        #endregion
    }
}
