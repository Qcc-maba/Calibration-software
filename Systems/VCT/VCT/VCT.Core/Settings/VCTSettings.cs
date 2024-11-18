using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Settings
{
    public class VCTSettings
    {
        #region constants

        public const string DEFAULT_SETTINGS_FOLDER = "Settings";
        public const string DEFAULT_FILE_NAME = "VCT.json";
        #endregion

        #region Properties

        public ComLayer.Tunnel[] Tunnels { get; set; }

        public VCTDeviceSettings[] DeviceSettings { get; set; }

        public TimeSpan PendingDevice_AwakePacketInterval_TimeSpan
        {
            get
            {
                return TimeSpan.FromSeconds(10);
            }
        }

        public TimeSpan PendingDevice_MaximumSilence_TimeSpan
        {
            get
            {
                return TimeSpan.FromMinutes(1);
            }
        }

        public TimeSpan PendingDevice_FirstAwakePacket_TimeSpan
        {
            get
            {
                return TimeSpan.FromSeconds(1);
            }
        }

        public long PendingDevice_MaxAwakePacketTimes { get; set; }
        public int ServerTimerInterval
        {
            get
            {
                return 800;
            }
        }

        //#region Firmware (OTA) Settings

        //public string OTA_LocalStorageFolder { get; set; }

        //public string OTA_RemoteStorageURL { get; set; }

        //#endregion

        #endregion

        #region ctor

        public VCTSettings()
        {
            //OTA_LocalStorageFolder = null;
            PendingDevice_MaxAwakePacketTimes = 5;
        }

        #endregion

        #region private methods
        private void Save(string fullPath, VCTSettings obj)
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

        //public string Get_OTA_LocalStorageFolder()
        //{
        //    if (String.IsNullOrEmpty(this.OTA_LocalStorageFolder))
        //    {
        //        var folder = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location), "Settings");
        //        this.OTA_LocalStorageFolder = folder;
        //    }

        //    Directory.CreateDirectory(this.OTA_LocalStorageFolder);
        //    //current/OTA
        //    return this.OTA_LocalStorageFolder;

        //}
        #endregion

        #region static

        public static string GetSettingFolder()
        {
            var folderName = Path.Combine(
                     Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                    Settings.VCTSettings.DEFAULT_SETTINGS_FOLDER);
            Directory.CreateDirectory(folderName);
            return folderName;
        }

        public static string GetSettingsFullPath()
        {
            return Path.Combine(GetSettingFolder(), DEFAULT_FILE_NAME);
        }

        public static VCTSettings Read()
        {
            VCTSettings _settings = null;
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
                                _settings = jSer.Deserialize(jReader, typeof(VCTSettings)) as VCTSettings;
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

        public static VCTSettings CreateDefaultSettings()
        {
            var defaultSettings = new VCTSettings()
            {
                Tunnels = new ComLayer.Tunnel[]
                 {
                    new ComLayer.Tunnel()
                        { Name = "VCTTunnelSettings",
                        Address = "127.0.0.1",
                        BacklogClients = 5000,
                        Ports = new int[] { 50000, 50050 }
                    }
                },
                DeviceSettings = new VCTDeviceSettings[]
                 {
                      new VCTDeviceSettings() {SettingsName="" }
                 }
            };

            return defaultSettings;
        }

        #endregion
    }
}
