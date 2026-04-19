using Maba.VCT.Libs.Trace;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel;
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

        /// <summary>Default HttpListener prefix for WebSocket (must end with /).</summary>
        public const string DEFAULT_WEBSOCKET_LISTEN_PREFIX = "http://localhost:5001/ws/";
        #endregion

        #region Members
        public string GeneralDBName { get { return "KyulanSyncDB"; } }
        public string PriorityDBName { get { return "Priority"; } }
        #endregion

        #region Properties

        public ComLayer.Tunnel[] Tunnels { get; set; }

        public DeviceSettings[] DeviceSettings { get; set; }

        /// <summary>
        /// HttpListener URL prefix for the WebSocket endpoint (must end with /).
        /// Clients use the matching ws:// or wss:// URL (see <see cref="NormalizeWebSocketListenPrefix"/>).
        /// </summary>
        public string WebSocketListenPrefix { get; set; }

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
                return 2000;
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
            WebSocketListenPrefix = DEFAULT_WEBSOCKET_LISTEN_PREFIX;
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
            catch (Exception ex)
            {
                Tracer.Info("[VCTSettings] Save failed: {0}", ex.Message);
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

        /// <summary>Process environment variable: when set to an absolute path, <see cref="GetSettingsFullPath"/> uses that file instead of the default under the executing assembly (tests/CI isolation).</summary>
        public const string VCT_SETTINGS_FULL_PATH_ENV = "VCT_SETTINGS_FULL_PATH";

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
            var env = Environment.GetEnvironmentVariable(VCT_SETTINGS_FULL_PATH_ENV);
            if (!string.IsNullOrWhiteSpace(env))
            {
                var p = env.Trim().Trim('"');
                var dir = Path.GetDirectoryName(p);
                if (!string.IsNullOrEmpty(dir))
                    Directory.CreateDirectory(dir);
                return p;
            }

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
            catch (Exception ex)
            {
                Tracer.Info("[VCTSettings] Read failed: {0}", ex.Message);
            }

            _settings = _settings ?? CreateDefaultSettings();

            if (string.IsNullOrWhiteSpace(_settings.WebSocketListenPrefix))
                _settings.WebSocketListenPrefix = DEFAULT_WEBSOCKET_LISTEN_PREFIX;
            else
                _settings.WebSocketListenPrefix = NormalizeWebSocketListenPrefix(_settings.WebSocketListenPrefix);

            _settings.Save();
            return _settings;
        }

        /// <summary>Ensures trailing slash and trims whitespace (HttpListener requirement).</summary>
        public static string NormalizeWebSocketListenPrefix(string prefix)
        {
            if (string.IsNullOrWhiteSpace(prefix))
                return DEFAULT_WEBSOCKET_LISTEN_PREFIX;
            var p = prefix.Trim();
            if (!p.EndsWith("/", StringComparison.Ordinal))
                p += "/";
            return p;
        }

        public static VCTSettings CreateDefaultSettings()
        {
            var defaultSettings = new VCTSettings()
            {
                WebSocketListenPrefix = DEFAULT_WEBSOCKET_LISTEN_PREFIX,
                Tunnels = new ComLayer.Tunnel[]
                 {
                    new ComLayer.Tunnel()
                    {
                        Name = "VCTTunnelSettings",
                        Address = "127.0.0.1",
                        BacklogClients = 5000,
                        Ports = new int[] { 50000, 50050 }
                    },
                    new ComLayer.Tunnel()
                    {
                        Name = "SerialDevice_AUTO",
                        SerialPortName = "AUTO",
                        SerialBaudRate = 9600,
                        SerialTimeout = 100
                    }
                },
                DeviceSettings = new DeviceSettings[]
                 {
                      new DeviceSettings()
                      {
                          SettingsName="",
                          IdentificationType= Core.DeviceSettings.IdentificationTypes.IDN
                      }

                 },
            };

            return defaultSettings;
        }

        #endregion
    }
}
