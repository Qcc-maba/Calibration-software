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

        /// <summary>
        /// Find attached instruments at startup instead of requiring a tunnel per instrument.
        /// <para>
        /// Discovery enumerates the USB and GPIB instruments that actually answer, and probes serial
        /// ports for their baud rate. Anything listed in <see cref="Tunnels"/> still opens exactly as
        /// configured and its serial port is never probed, so a static entry remains available as an
        /// override for an instrument that does not answer *IDN?.
        /// </para>
        /// <para>
        /// This is what keeps the configuration free of per-instrument detail. It also removes two
        /// failure modes that static tunnels caused: two instruments configured on one COM port, and a
        /// tunnel for an instrument that had been unplugged wedging the device tick on its bus error.
        /// </para>
        /// </summary>
        public bool AutoDiscoverTransports { get; set; } = true;

        /// <summary>
        /// How often, in seconds, to look for instruments that were plugged in after startup.
        /// 0 disables it.
        /// <para>
        /// Discovery used to run once, during startup. Unplugging a logger and plugging it back in
        /// therefore ended the session for good: the pending device is dropped the moment its link
        /// reports disconnected, and nothing ever looked again - not even the app's manual refresh,
        /// which only redraws the client (MBA-962 item 4).
        /// </para>
        /// <para>
        /// Thirty seconds rather than the two-second device tick because a serial pass physically
        /// opens each candidate port and sends *IDN?; doing that every couple of seconds would
        /// disturb instruments that are mid-measurement for no benefit.
        /// </para>
        /// </summary>
        public int RediscoverIntervalSeconds { get; set; } = 30;

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

        /// <summary>
        /// How often, in milliseconds, the device tick runs. It is the rate at which each session is
        /// asked "are you free?", NOT a rate limit on the instrument: <see cref="Device.Sessions.BaseSession"/>
        /// dequeues one request only once the previous reply has arrived, so a shorter tick removes
        /// dead time between commands and cannot make the server talk over a device.
        /// <para>
        /// It was a hard-coded 2000. Every command in the start-up sequence therefore cost two
        /// seconds of waiting whatever the instrument's own latency was, and a Hydra configured for
        /// 20 channels spent 40 seconds on FUNC commands alone before it could be told to scan -
        /// about a minute from the operator pressing confirm to the first reading (MBA-962).
        /// </para>
        /// <para>
        /// 500 rather than something smaller because the tick also drives the LOG_COUNT? poll that
        /// runs continuously while a scan is in progress: at 9600 baud, and in the log, that traffic
        /// is not free. 500 makes start-up four times quicker while leaving the steady-state
        /// polling at a rate the instrument and the log file can carry.
        /// </para>
        /// </summary>
        public int ServerTimerInterval { get; set; } = 500;

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

            _settings.ServerTimerInterval = NormalizeServerTimerInterval(_settings.ServerTimerInterval);

            _settings.Save();
            return _settings;
        }

        /// <summary>The value the old hard-coded getter returned, and therefore the value Save() wrote
        /// into every station's VCT.json before this became a real setting.</summary>
        internal const int LEGACY_SERVER_TIMER_INTERVAL = 2000;

        /// <summary>Default and bounds for <see cref="ServerTimerInterval"/>.</summary>
        internal const int DEFAULT_SERVER_TIMER_INTERVAL = 500;
        internal const int MIN_SERVER_TIMER_INTERVAL = 50;
        internal const int MAX_SERVER_TIMER_INTERVAL = 5000;

        /// <summary>
        /// Decides the tick a station actually runs at, and it exists because of an upgrade problem
        /// rather than a preference.
        /// <para>
        /// <c>ServerTimerInterval</c> used to be a get-only property returning 2000, and
        /// <see cref="Save"/> wrote that number into the settings file of every station ever
        /// installed. Those files are all sitting on disk, and the installer deliberately does not
        /// overwrite a station's tuned settings - so making the property settable would have left
        /// every existing station on the slow tick while only fresh installs got the new one.
        /// A file saying exactly 2000 is an artifact of the old build, not an operator's decision,
        /// so it is migrated. A station that genuinely wants a two-second tick can say 1999 or 2001.
        /// </para>
        /// <para>
        /// Anything outside the bounds is refused rather than obeyed: a mistyped 5 would spin the
        /// device tick, and a mistyped 50000 would look exactly like a hung server.
        /// </para>
        /// </summary>
        internal static int NormalizeServerTimerInterval(int configured)
        {
            if (configured == LEGACY_SERVER_TIMER_INTERVAL)
            {
                Tracer.Info("[VCTSettings] ServerTimerInterval {0}ms came from the old hard-coded default; using {1}ms.",
                            LEGACY_SERVER_TIMER_INTERVAL, DEFAULT_SERVER_TIMER_INTERVAL);
                return DEFAULT_SERVER_TIMER_INTERVAL;
            }

            if (configured < MIN_SERVER_TIMER_INTERVAL || configured > MAX_SERVER_TIMER_INTERVAL)
            {
                Tracer.Info("[VCTSettings] ServerTimerInterval {0}ms is outside {1}-{2}ms; using {3}ms.",
                            configured, MIN_SERVER_TIMER_INTERVAL, MAX_SERVER_TIMER_INTERVAL, DEFAULT_SERVER_TIMER_INTERVAL);
                return DEFAULT_SERVER_TIMER_INTERVAL;
            }

            return configured;
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
