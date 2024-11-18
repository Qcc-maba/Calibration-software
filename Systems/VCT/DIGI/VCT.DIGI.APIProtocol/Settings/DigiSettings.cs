using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.DIGI.APIProtocol.Settings
{
    public class DigiSettings
    {
        #region Properties

        public const string DEFAULT_SETTINGS_FOLDER = "Settings";
        public const string DEFAULT_SETTINGS_FILE_NAME = "DigiServer.json";

        public ComLayer.Tunnel[] Tunnels { get; set; }

        #endregion

        #region Public Static Methods

        public static DigiSettings CreateDefaultSettings()
        {
            var defaultSettings= new DigiSettings()
            {
                Tunnels = new ComLayer.Tunnel[]
                {
                    new ComLayer.Tunnel()
                    {
                        Name = "DigiTunnelSettings",
                        Address = "127.0.0.1",
                        BacklogClients = 5000,
                        Ports = new int[] { 50006, 50060 },
                    }
                }
            };

            return defaultSettings;
        }

        public static string GetSettingsFolder()
        {
            var folder = Path.Combine(
                Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)
                , DEFAULT_SETTINGS_FOLDER);
            Directory.CreateDirectory(folder);
            return Path.Combine(folder, DEFAULT_SETTINGS_FILE_NAME);
        }

        public static DigiSettings Read(bool CreateWhenMissing = true)
        {
            DigiSettings _settings = null;
            var filenamePath = GetSettingsFolder();
            try
            {
                if (File.Exists(filenamePath))
                {
                    var Jset = new Newtonsoft.Json.JsonSerializerSettings()
                    {
                        Formatting = Newtonsoft.Json.Formatting.Indented
                    };
                    // var fullPath = Path.Combine(filenamePath, DEFAULT_SETTINGS_FILE_NAME);
                    using (var st = new FileStream(filenamePath, FileMode.OpenOrCreate, FileAccess.Read))
                    {
                        using (var txtReader = new StreamReader(st))
                        {
                            using (var jReader = new Newtonsoft.Json.JsonTextReader(txtReader))
                            {
                                var jSer = Newtonsoft.Json.JsonSerializer.Create(Jset);
                                return jSer.Deserialize(jReader, typeof(DigiSettings)) as DigiSettings;
                            }
                        }
                    }
                }
                else
                {
                    if (CreateWhenMissing)
                    {
                        try
                        {
                            _settings = new DigiSettings();
                            _settings.Save();
                        }
                        catch { }
                    }
                }
            }
            catch
            { }

            _settings = _settings ?? new DigiSettings();

            return _settings;
        }

        #endregion

        #region Private Methods

        public void Save()
        {
            try
            {
                var Jset = new Newtonsoft.Json.JsonSerializerSettings()
                {
                    Formatting = Newtonsoft.Json.Formatting.Indented
                };
                var fullPath = GetSettingsFolder();
                using (var st = new FileStream(fullPath, FileMode.OpenOrCreate, FileAccess.Write))
                {
                    using (var txtWriter = new StreamWriter(st))
                    {
                        using (var jWrite = new Newtonsoft.Json.JsonTextWriter(txtWriter))
                        {
                            var jSer = Newtonsoft.Json.JsonSerializer.Create(Jset);
                            jSer.Serialize(jWrite, this);
                        }
                    }
                }
            }
            catch
            {
            }
        }

        #endregion
    }
}
