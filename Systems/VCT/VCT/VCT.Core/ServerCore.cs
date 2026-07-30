using Maba.DAL.BaseDAL;
using Maba.VCT.Accessories;
using Maba.VCT.ComLayer.Com_Layer;
using Maba.VCT.Common;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Threading.Tasks;
using System.Diagnostics.CodeAnalysis;
using System.Management;
using System.Timers;
using System.Web;
using static System.Net.WebRequestMethods;

namespace Maba.VCT.Core
{
    /// <summary>
    /// The server orchestrator. Opens the configured tunnels (TCP and serial), polls newly
    /// connected links with an identification packet until they report a serial number, promotes
    /// them to identified <see cref="Device.HardwareDeviceHost"/> instances, and hosts the
    /// WebSocket listener that streams measurements to the web app.
    /// See docs/architecture.md for the end-to-end pipeline.
    /// </summary>
    public class ServerCore
    {
        #region members

        private Dictionary<string, DeviceSettings> Dic_DeviceSettings = new Dictionary<string, DeviceSettings>();

        #endregion

        #region properties

        public Settings.VCTSettings CurrentServerSettings { get; private set; }

        public Events.EventsBus MainEventsBus { get; private set; }

        #endregion

        #region Members

        private Timer TimerManager_DeviceHost = null;

        private MyReaderWriterLockSlim<ConcurrentDictionary<string, Device.HardwareDeviceHost>> DeviceHost_Slim = new MyReaderWriterLockSlim<ConcurrentDictionary<string, Device.HardwareDeviceHost>>(new ConcurrentDictionary<string, Device.HardwareDeviceHost>());
        private MyReaderWriterLockSlim<ConcurrentDictionary<string, Device.WebSocketDeviceHost>> WSDeviceHost_Slim = new MyReaderWriterLockSlim<ConcurrentDictionary<string, Device.WebSocketDeviceHost>>(new ConcurrentDictionary<string, Device.WebSocketDeviceHost>());
        private MyReaderWriterLockSlim<List<Device.DeviceHostPending>> DeviceHost_Pending_Slim = new MyReaderWriterLockSlim<List<Device.DeviceHostPending>>(new List<Device.DeviceHostPending>());

        private List<Socket> Device_MainSockets = null;

        #region Websocket Members

        private HttpListener _listener;
        private string WebSocketAddress;
        // HttpListenerContext context; // Removed as class member to avoid thread-safety issues in async loop
        #endregion



        #region DB Members
        public MSSqlServer connector = null;
        #endregion

        /// <summary>
        /// When true, pending hardware (SN not yet known) will not receive identification packets
        /// (e.g. *IDN?) until <see cref="EnableHardwareIdentification"/> is called — used from console host after operator confirmation.
        /// Windows Service and other hosts leave this false so behavior stays immediate.
        /// </summary>
        public bool DeferHardwareIdentificationPackets { get; set; }

        private readonly object _hardwareIdentificationLock = new object();
        private DateTime? _hardwareIdentificationStartedUtc;

        #endregion

        #region ctor

        public ServerCore()
        {
            this.MainEventsBus = new Events.EventsBus();
            this.MainEventsBus.DeviceOnIncomingEvent += MainEventsBus_DeviceOnIncomingEvent;
            CurrentServerSettings = new Settings.VCTSettings();
        }

        private void MainEventsBus_DeviceOnIncomingEvent(object o, Events.DeviceEventArgs e)
        {
            // If the event came from a Hardware device, broadcast it to all WebSocket clients
            if (e.Device is Device.HardwareDeviceHost hardwareDevice)
            {
                Libs.Trace.Tracer.Info("[ServerCore] DeviceOnIncomingEvent from SN={0}, packet={1}", hardwareDevice.SN, e.Packet?.ToString()?.Trim());
                BroadcastToWebSockets(hardwareDevice, e.Packet);
            }
            // If the event came from a WebSocket client with a Status:Stop command, disconnect all hardware devices
            else if (e.Device is Device.WebSocketDeviceHost && e.Packet is Common.Protocol_Parser.WebSocketMessage.StatusMessage statusMsg)
            {
                if (string.Equals(statusMsg.Value, "Stop", StringComparison.OrdinalIgnoreCase))
                {
                    Libs.Trace.Tracer.Info("[ServerCore] Received Stop command from WebSocket client - disconnecting all hardware devices");
                    DeviceHost_Slim.MyReadLock(list =>
                    {
                        foreach (var dev in list.Values)
                        {
                            try
                            {
                                dev.Disconnect();
                                Libs.Trace.Tracer.Info("[ServerCore] Disconnected device SN={0}", dev.SN);
                            }
                            catch (Exception ex)
                            {
                                Libs.Trace.Tracer.Info("[ServerCore] Error disconnecting device: {0}", ex.Message);
                            }
                        }
                    });
                }
                else if (string.Equals(statusMsg.Value, "Start", StringComparison.OrdinalIgnoreCase))
                {
                    Libs.Trace.Tracer.Info("[ServerCore] Received Start from WebSocket — enabling Hydra hardware identification (*IDN? / pending scan).");
                    EnableHardwareIdentification();
                    // Do not wait for the next timer tick: send identification / run pending-device logic immediately.
                    TriggerImmediatePendingDevicePollAfterWsStart();
                }
            }
        }

        /// <summary>Requires <see cref="TimerManager_DeviceHost"/> from startup; otherwise no-op. Elided from unit line coverage.</summary>
        [ExcludeFromCodeCoverage]
        private void TriggerImmediatePendingDevicePollAfterWsStart()
        {
            if (TimerManager_DeviceHost == null)
            {
                Libs.Trace.Tracer.Info("[ServerCore] WebSocket Start: device timer not ready — skipped immediate poll.");
                return;
            }

            try
            {
                TimerManager_Device_Elapsed(null, null);
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[ServerCore] WebSocket Start: immediate device poll failed: {0}", ex.Message);
            }
        }

        /// <summary>Exercised via <see cref="EventsBus.Fire_OnIncomingEvent"/> in tests; kept out of line-coverage threshold.</summary>
        [ExcludeFromCodeCoverage]
        private void BroadcastToWebSockets(Device.HardwareDeviceHost device, IPacket packet)
        {
            if (device == null || packet == null) return;

            WSDeviceHost_Slim.MyReadLock(list =>
            {
                Libs.Trace.Tracer.Info("[WS Broadcast] Total WS clients in list: {0}", list.Count);
                foreach (var wsHost in list.Values)
                {
                    try
                    {
                        var com = wsHost.InternalComLayer;
                        if (com == null || !com.IsConnected)
                        {
                            Libs.Trace.Tracer.Info("[WS TX] Skipped - connection dead (com={0}, connected={1})",
                                com == null ? "null" : "ok", com?.IsConnected.ToString() ?? "N/A");
                            continue;
                        }

                        // Parse E,SN,CH1,VAL1[,CH2,VAL2,...] format from device
                        // SN may contain commas (e.g. "FLUKE,2625A"), so use device.SN to find where channels start
                        var raw = packet.ToString().Replace("\r", "").Replace("\n", "").Trim();
                        if (!raw.StartsWith("E,")) continue;

                        // Strip "E," prefix and the SN to get channel/value pairs
                        var snPrefix = "E," + device.SN + ",";
                        if (!raw.StartsWith(snPrefix)) continue;
                        var channelData = raw.Substring(snPrefix.Length); // "ch1,val1,ch2,val2,..."
                        var parts = channelData.Split(',');
                        Libs.Trace.Tracer.Info("[WS TX] Parsed channelData: {0} ({1} parts, {2} channel-value pairs)",
                            channelData, parts.Length, parts.Length / 2);
                        if (parts.Length < 2 || parts.Length % 2 != 0) continue;

                        string timeStr = DateTime.Now.ToString("MM/dd/yyyy HH:mm:ss");

                        // Use association data from WebSocket client if available, otherwise fall back to device SN
                        var wsDeviceId = !string.IsNullOrEmpty(wsHost.AssociatedDeviceId) ? wsHost.AssociatedDeviceId : device.SN;
                        var wsLoggerId = !string.IsNullOrEmpty(wsHost.AssociatedLoggerId) ? wsHost.AssociatedLoggerId : device.SN;
                        var wsBatchId = !string.IsNullOrEmpty(wsHost.AssociatedBatchId) ? wsHost.AssociatedBatchId : "LIVE";

                        var wsUnits = !string.IsNullOrEmpty(wsHost.AssociatedUnits) ? wsHost.AssociatedUnits : "Celsius";
                        var wsResolution = !string.IsNullOrEmpty(wsHost.AssociatedResolution) ? wsHost.AssociatedResolution : "2";

                        var sb = new System.Text.StringBuilder();
                        sb.AppendFormat("CMD:\"LoggerData\", DeviceID:\"{0}\", LoggerID:\"{1}\", BatchID:\"{2}\", Time:\"{3}\", Units:\"{4}\", Resolution:\"{5}\"",
                            wsDeviceId, wsLoggerId, wsBatchId, timeStr, wsUnits, wsResolution);

                        for (int i = 0; i + 1 < parts.Length; i += 2)
                        {
                            sb.AppendFormat(", Channel:\"{0}\", Value:\"{1}\"", parts[i], parts[i + 1]);
                        }

                        var wsMessage = sb.ToString();
                        com.SendString(wsMessage);
                        Libs.Trace.Tracer.Info("[WS TX] {0}", wsMessage);
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info("Failed to broadcast to WebSocket: {0}", ex.Message);
                    }
                }
            });
        }

        #endregion

        #region public Methods

        /// <summary>
        /// Begins sending identification traffic to unidentified pending devices and applies silence timeout from this moment
        /// (or from device connection time, whichever is later). No-op if deferred mode is off.
        /// </summary>
        public void EnableHardwareIdentification()
        {
            if (!DeferHardwareIdentificationPackets)
                return;

            lock (_hardwareIdentificationLock)
            {
                if (_hardwareIdentificationStartedUtc.HasValue)
                    return;

                _hardwareIdentificationStartedUtc = DateTime.UtcNow;
            }

            Libs.Trace.Tracer.Info("[STARTUP] Hardware identification enabled — *IDN? / identification packets will be sent to pending devices.");
        }

        [ExcludeFromCodeCoverage]
        public void Start()
        {
            Start(Settings.VCTSettings.Read());
        }

        /// <summary>Startup path: serial/TCP tunnels, timers, WebSocket listener, DB. Covered by integration/E2E; excluded from unit-test line coverage.</summary>
        [ExcludeFromCodeCoverage]
        public async void Start(Settings.VCTSettings _Settings)
        {
            CurrentServerSettings = _Settings;
            WebSocketAddress = Settings.VCTSettings.NormalizeWebSocketListenPrefix(_Settings?.WebSocketListenPrefix);

            Libs.Trace.Tracer.Info("========================================");
            Libs.Trace.Tracer.Info("  SERVER STARTUP SEQUENCE");
            Libs.Trace.Tracer.Info("========================================");

            #region cache device settings

            Dic_DeviceSettings.Clear();
            foreach (var s in CurrentServerSettings.DeviceSettings)
            {
                Dic_DeviceSettings[s.SettingsName] = s;
            }
            Libs.Trace.Tracer.Info($"[STARTUP] Loaded {Dic_DeviceSettings.Count} device settings");

            #endregion

            //Device.OTA.OTAService.CurrentServerSettings = CurrentServerSettings;
            Device_MainSockets = new List<Socket>();

            Libs.Trace.Tracer.Info($"[STARTUP] Configured tunnels: {CurrentServerSettings.Tunnels.Length}");

            int serialCount = 0;
            int tcpCount = 0;

            foreach (var t in CurrentServerSettings.Tunnels)
            {
                if (t.GpibPrimaryAddress >= 0)
                {
                    // GPIB tunnel: open a GpibCom on the configured primary address (needs NI-488.2).
                    Libs.Trace.Tracer.Info($"[STARTUP] Opening GPIB board {t.GpibBoardIndex} address {t.GpibPrimaryAddress}...");
                    try
                    {
                        var gpib = new ComLayer.GpibCom(t.GpibPrimaryAddress, t.GpibBoardIndex, t);
                        AddDevice_Pending_ComLayer(gpib);
                        gpib.Open();
                        Libs.Trace.Tracer.Info($"[STARTUP] GPIB address {t.GpibPrimaryAddress} opened OK");
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info($"[STARTUP] FAILED to open GPIB address {t.GpibPrimaryAddress}: {ex.Message}");
                    }
                }
                else if (!string.IsNullOrEmpty(t.SerialPortName))
                {
                    serialCount++;

                    string actualPort;
                    if (string.Equals(t.SerialPortName, "AUTO", StringComparison.OrdinalIgnoreCase))
                    {
                        var detectedPort = DetectUsbToSerialPort();
                        actualPort = detectedPort ?? t.SerialPortName;

                        if (detectedPort != null)
                        {
                            Libs.Trace.Tracer.Info($"[STARTUP] Auto-detected USB-to-Serial: {detectedPort} (config had {t.SerialPortName})");
                        }
                        else
                        {
                            Libs.Trace.Tracer.Info($"[STARTUP] No USB-to-Serial detected, using config: {t.SerialPortName}");
                        }
                    }
                    else
                    {
                        actualPort = t.SerialPortName.Trim();
                        Libs.Trace.Tracer.Info($"[STARTUP] Using explicit serial port from config (no USB auto-detect): {actualPort}");
                    }

                    Libs.Trace.Tracer.Info($"[STARTUP] Opening serial port {actualPort} at {t.SerialBaudRate} baud...");

                    // Serial tunnel: open SerialCom directly
                    try
                    {
                        var serialCom = new ComLayer.SerialCom(actualPort, t.SerialBaudRate, t.SerialTimeout, t);
                        AddDevice_Pending_ComLayer(serialCom);
                        serialCom.Open();
                        Libs.Trace.Tracer.Info($"[STARTUP] Serial port {actualPort} opened OK ({t.SerialBaudRate} baud)");
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info($"[STARTUP] FAILED to open serial port {actualPort}: {ex.Message}");
                    }
                }
                else
                {
                    tcpCount++;
                    // TCP tunnel (existing behavior)
                    Device_MainSockets.AddRange(StartSockets(t, DevicesSocket_Accpet_AsyncCallback));
                }
            }

            Libs.Trace.Tracer.Info($"[STARTUP] Serial ports: {serialCount}, TCP tunnels: {tcpCount}");

            #region Device Host Timer init

            TimerManager_DeviceHost = new Timer();
            TimerManager_DeviceHost.Interval = CurrentServerSettings.ServerTimerInterval;
            TimerManager_DeviceHost.Elapsed += TimerManager_Device_Elapsed;
            TimerManager_DeviceHost.AutoReset = true;
            TimerManager_DeviceHost.Start();
            Libs.Trace.Tracer.Info($"[STARTUP] Device timer started (interval={CurrentServerSettings.ServerTimerInterval}ms)");

            #endregion

            #region WebSocket
            Libs.Trace.Tracer.Info($"[STARTUP] Initializing WebSocket on {WebSocketAddress}...");
            WebSocketInit();
            #endregion

            #region DB connector
            try
            {
                connector = new MSSqlServer(CurrentServerSettings.GeneralDBName);
                await connector.OpenAsync();
                Libs.Trace.Tracer.Info("[STARTUP] DB connected OK.");
            }
            catch (Exception dbEx)
            {
                Libs.Trace.Tracer.Info($"[STARTUP] DB connection FAILED (non-fatal): {dbEx.Message}");
            }
            #endregion

            Libs.Trace.Tracer.Info("========================================");
            Libs.Trace.Tracer.Info("  STARTUP SUMMARY");
            Libs.Trace.Tracer.Info($"  Serial ports: {serialCount}");
            Libs.Trace.Tracer.Info($"  TCP tunnels:  {tcpCount}");
            Libs.Trace.Tracer.Info($"  WebSocket:    {WebSocketAddress}");
            Libs.Trace.Tracer.Info($"  DB:           {(connector != null ? "connected" : "not connected")}");
            Libs.Trace.Tracer.Info("========================================");
        }

        [ExcludeFromCodeCoverage]
        private async void WebSocketInit()
        {
            try
            {
                _listener = new HttpListener();
                _listener.Prefixes.Add(WebSocketAddress);
                var wsHint = WebSocketAddress.Replace("http://", "ws://").Replace("https://", "wss://");
                Libs.Trace.Tracer.Info("[WS] Web app .env (must match listener path, usually trailing slash): NEXT_PUBLIC_WEBSOCKET_URL={0}", wsHint);

                Libs.Trace.Tracer.Info($"[WS] Starting HttpListener on {WebSocketAddress}...");
                _listener.Start();
                Libs.Trace.Tracer.Info($"[WS] WebSocket server LISTENING on {WebSocketAddress}");

                while (_listener.IsListening)
                {
                    try
                    {
                        var localContext = await _listener.GetContextAsync();
                        var ctx = localContext;
                        Libs.Trace.Tracer.Info($"[WS] Incoming connection from {ctx.Request.RemoteEndPoint} path={ctx.Request.Url.AbsolutePath}");
                        _ = Task.Run(async () => { await HandleWebSocketConnectionAsync(ctx); });
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info("[WS] Accept error: {0}", ex.Message);
                    }
                }
            }
            catch (HttpListenerException hlex)
            {
                Libs.Trace.Tracer.Info($"[WS] FAILED to start listener: {hlex.Message} (ErrorCode={hlex.ErrorCode})");
                Libs.Trace.Tracer.Info($"[WS] HINT: Run 'netsh http add urlacl url={WebSocketAddress} user=Everyone' as admin");
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info($"[WS] Init error: {ex.GetType().Name}: {ex.Message}");
            }
        }

        [ExcludeFromCodeCoverage]
        private async Task HandleWebSocketConnectionAsync(HttpListenerContext ctx)
        {
            if (ctx == null) return;

            if (!ctx.Request.IsWebSocketRequest)
            {
                try { ctx.Response.StatusCode = 400; ctx.Response.Close(); }
                catch (Exception ex)
                {
                    Libs.Trace.Tracer.Info("[WS] Non-WebSocket request: failed to send 400: {0}", ex.Message);
                }
                return;
            }

            HttpListenerWebSocketContext wsCtx;
            try
            {
                wsCtx = await ctx.AcceptWebSocketAsync(null);
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[WS] Upgrade failed: {0}", ex.Message);
                return;
            }

            if (wsCtx == null || wsCtx.WebSocket == null)
            {
                Libs.Trace.Tracer.Info("[WS] Upgrade returned null");
                return;
            }

            var webSocket = wsCtx.WebSocket;
            if (webSocket.State != WebSocketState.Open)
            {
                Libs.Trace.Tracer.Info("[WS] Socket state after upgrade: {0}", webSocket.State.ToString());
                return;
            }

            WebSocketCom wsc = null;
            WebSocketDeviceHost wsdh = null;
            try
            {
                wsc = new WebSocketCom(webSocket);
                wsdh = new WebSocketDeviceHost(MainEventsBus, wsc, "Eliran");
                WSDeviceHost_Slim.MyWriteLock(list =>
                {
                    list["Eliran"] = wsdh;
                });
                MainEventsBus.Fire_WebSocketConnection(this, new Events.DeviceConnectionEventArgs(wsdh));
                Libs.Trace.Tracer.Info("[WS] Client connected (state={0})", webSocket.State.ToString());

                await wsc.RunReceiveLoopAsync(wsc.ReadLoopCancellation).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[WS] Host/receive error: {0}", ex.Message);
            }
            finally
            {
                WSDeviceHost_Slim.MyWriteLock(list =>
                {
                    list.TryRemove("Eliran", out _);
                });
                Libs.Trace.Tracer.Info("[WS] Client session ended (state={0})", webSocket?.State.ToString());
            }
        }

        public void Stop()
        {
            lock (_hardwareIdentificationLock)
            {
                _hardwareIdentificationStartedUtc = null;
            }

            CurrentServerSettings = null;

            #region Close WebSocket HttpListener

            try
            {
                if (_listener != null)
                {
                    if (_listener.IsListening)
                        _listener.Stop();
                    _listener.Close();
                }
            }
            catch (Exception)
            {
            }
            _listener = null;

            #endregion

            if (Device_MainSockets != null)
            {
                foreach (var item in Device_MainSockets)
                {
                    item.Close();
                }
            }

            Device_MainSockets = null;

            #region Device_Pending

            DeviceHost_Pending_Slim.MyWriteLock(list =>
        {
            foreach (var dev in list)
            {
                try
                {
                    dev.D.Disconnect();
                }
                catch (Exception)
                {
                }
            }
            list.Clear();
        });

            #endregion

            #region Devices

            DeviceHost_Slim.MyWriteLock(list =>
            {
                foreach (var g in list)
                {
                    try
                    {
                        g.Value.InternalComLayer.Close();
                    }
                    catch (Exception)
                    {
                    }
                }
                list.Clear();
            });

            #endregion

            #region Close Device Host Timer

            if (TimerManager_DeviceHost != null)
            {
                TimerManager_DeviceHost.Elapsed -= TimerManager_Device_Elapsed;
                TimerManager_DeviceHost.Stop();
                TimerManager_DeviceHost = null;
            }

            #endregion
        }

        private DeviceSettings Lookup4Settings(string name)
        {
            DeviceSettings value = null;
            if (Dic_DeviceSettings.TryGetValue(name, out value))
            {
                if (value != null)
                {
                    return value;
                }
            }

            return new DeviceSettings();
        }

        public void AddDevice_Pending_ComLayer(ComLayer.IComLayer layer, string SN = "")
        {
            var deviceSettings = Lookup4Settings(layer.ParentTunnel.Name);

            var g = new Device.DeviceHostPending();

            g = new Device.DeviceHostPending()
            {
                D = new Device.HardwareDeviceHost(MainEventsBus, layer, deviceSettings.Clone())
            };
            DeviceHost_Pending_Slim.MyWriteLock(list =>
                    {
                        list.Add(g);
                    });

            //MainEventsBus.Fire_DeviceConnection(this, new Events.DeviceConnectionEventArgs(g.D));
        }

        public Task<Device.HardwareDeviceHost> GetDeviceAsync(string sn)
        {
            return Task.Run<Device.HardwareDeviceHost>(() => GetDevice(sn));
        }

        public Device.HardwareDeviceHost GetDevice(string sn)
        {
            Device.HardwareDeviceHost dev = null;

            DeviceHost_Slim.MyReadLock(list =>
            {
                list.TryGetValue(sn, out dev);
            });

            return dev;
        }

        //public Task<Device.OTA.UploadFileResponse> RemoteUploadFileRequestAsync(string code, byte[] data, bool overide)
        //{
        //    return Task.Factory.StartNew<Device.OTA.UploadFileResponse>(() =>
        //    {
        //        var metadata = new Device.OTA.OTA_Metadata();
        //        metadata.FileCode = code;
        //        var res = Device.OTA.OTAService.UploadOTAFile(metadata, data, overide);

        //        return res == null ? null : res;
        //    });
        //}


        #endregion

        #region Private methods

        /// <summary>
        /// Auto-detect USB-to-Serial COM port using WMI.
        /// Prioritizes USB-to-Serial adapters (Prolific, FTDI, CH340, CP210x) over Bluetooth serial ports.
        /// Returns the detected port name, or null if none found.
        /// </summary>
        /// <summary>Host/OS-specific (WMI). Not unit-tested; covered manually on hardware.</summary>
        [ExcludeFromCodeCoverage]
        private string DetectUsbToSerialPort()
        {
            try
            {
                var usbKeywords = new[] { "USB-to-Serial", "USB Serial", "FTDI", "CH340", "CP210", "Prolific" };
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'"))
                {
                    var ports = new List<Tuple<string, string>>(); // <portName, deviceName>
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (string.IsNullOrEmpty(name)) continue;

                        // Extract COM port number from name like "Prolific USB-to-Serial Comm Port (COM9)"
                        var match = System.Text.RegularExpressions.Regex.Match(name, @"\(COM(\d+)\)");
                        if (!match.Success) continue;

                        var portName = "COM" + match.Groups[1].Value;
                        ports.Add(Tuple.Create(portName, name));
                        Libs.Trace.Tracer.Info("[AutoDetect] Found: {0} = {1}", portName, name);
                    }

                    // Prioritize USB-to-Serial adapters
                    foreach (var port in ports)
                    {
                        foreach (var keyword in usbKeywords)
                        {
                            if (port.Item2.IndexOf(keyword, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                Libs.Trace.Tracer.Info("[AutoDetect] Selected USB-to-Serial: {0} ({1})", port.Item1, port.Item2);
                                return port.Item1;
                            }
                        }
                    }

                    // No USB-to-Serial found, return first non-Bluetooth port if any
                    foreach (var port in ports)
                    {
                        if (port.Item2.IndexOf("Bluetooth", StringComparison.OrdinalIgnoreCase) < 0)
                        {
                            Libs.Trace.Tracer.Info("[AutoDetect] Selected non-BT port: {0} ({1})", port.Item1, port.Item2);
                            return port.Item1;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[AutoDetect] WMI query failed: {0}", ex.Message);
            }
            return null;
        }

        [ExcludeFromCodeCoverage]
        private void DevicesSocket_Accpet_AsyncCallback(IAsyncResult ar)
        {
            try
            {
                //var _state = (Tuple<ComLayer.Tunnel, Socket>)ar.AsyncState;
                var _state = (Socket)ar.AsyncState;

                try
                {
                    var newSocket = _state.EndAccept(ar);
                    var s = new ComLayer.SocketCom(newSocket);
                    this.AddDevice_Pending_ComLayer(s);
                    s.Open();
                }
                catch
                {
                }

                _state.BeginAccept(new AsyncCallback(DevicesSocket_Accpet_AsyncCallback), _state);
            }
            catch
            {

            }
        }

        [ExcludeFromCodeCoverage]
        private Socket[] StartSockets(ComLayer.Tunnel tunnel, AsyncCallback acceptCallback)
        {
            var sockets = new List<Socket>();
            if (tunnel.Ports != null && tunnel.Ports.Length > 0)
            {
                foreach (var t in tunnel.Ports)
                {
                    try
                    {
                        //var ip = String.IsNullOrEmpty(tunnel.Address) ? IPAddress.Any : Dns.GetHostEntry(tunnel.Address).AddressList.FirstOrDefault();
                        var ip = String.IsNullOrEmpty(tunnel.Address) ? IPAddress.Any : Dns.GetHostEntry(tunnel.Address).AddressList.Where(a => a.AddressFamily == AddressFamily.InterNetwork).FirstOrDefault();

                        var ep = new IPEndPoint(ip, t);
                        var s = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
                        s.Bind(ep);
                        s.Listen(tunnel.BacklogClients);
                        s.BeginAccept(new AsyncCallback(acceptCallback), new Tuple<ComLayer.Tunnel, Socket>(tunnel, s));
                        sockets.Add(s);
                    }
                    catch
                    {
                    }
                }
                return sockets.ToArray();
            }
            else
            {
                return new Socket[0];
            }
        }

        #endregion

        #region Timer Members

        List<Device.DeviceHostPending> _TempDeviceHost = new List<Device.DeviceHostPending>();


        /// <summary>Long-running timer orchestration; validated in integration/manual runs.</summary>
        [ExcludeFromCodeCoverage]
        void TimerManager_Device_Elapsed(object sender, ElapsedEventArgs e)
        {
            if (TimerManager_DeviceHost == null)
                return;

            DateTime NowTime = DateTime.UtcNow;

            #region Pending

            bool ScanRemoved = true;
            try
            {
                _TempDeviceHost.Clear();
                DeviceHost_Pending_Slim.MyReadLock((list) =>
                {
                    Device.DeviceHostPending dev = null;
                    TimeSpan pendinHydra2lenceTime;
                    for (int i = list.Count - 1; i >= 0; i--)
                    {
                        dev = list[i];
                        if (!dev.D.IsConnected)
                        {
                            dev.D.Disconnect();
                            dev.Remove = true;
                        }
                        else
                        {
                            if (dev.D.SN == null)
                            {
                                DateTime? idnStartedUtc;
                                lock (_hardwareIdentificationLock)
                                {
                                    idnStartedUtc = _hardwareIdentificationStartedUtc;
                                }

                                if (DeferHardwareIdentificationPackets && !idnStartedUtc.HasValue)
                                {
                                    // Operator has not confirmed yet: do not send *IDN? / identification, do not disconnect for silence.
                                }
                                else
                                {
                                    DateTime silenceBaseline = dev.D.InternalComLayer.CreationTime;
                                    if (DeferHardwareIdentificationPackets && idnStartedUtc.HasValue)
                                    {
                                        silenceBaseline = dev.D.InternalComLayer.CreationTime > idnStartedUtc.Value
                                            ? dev.D.InternalComLayer.CreationTime
                                            : idnStartedUtc.Value;
                                    }

                                    pendinHydra2lenceTime = NowTime - silenceBaseline;

                                    if (pendinHydra2lenceTime > CurrentServerSettings.PendingDevice_MaximumSilence_TimeSpan)
                                    {
                                        dev.D.Disconnect();
                                        dev.Remove = true;
                                    }
                                    else
                                    {
                                        var hwPending = dev.D as Device.HardwareDeviceHost;
                                        var idPacket = hwPending?.DeviceSettings?.IdentificationPacket
                                            ?? CurrentServerSettings.DeviceSettings?.FirstOrDefault()?.IdentificationPacket;
                                        if (idPacket == null)
                                        {
                                            Libs.Trace.Tracer.Info(
                                                "[PENDING] No IdentificationPacket (check DeviceSettings / JSON). Tunnel={0}, SN unset.",
                                                dev.D.InternalComLayer?.ParentTunnel?.Name ?? "?");
                                        }
                                        else
                                        {
                                            Libs.Trace.Tracer.Info(
                                                "[PENDING] Sending identification to pending device (tunnel={0}, defer={1})",
                                                dev.D.InternalComLayer?.ParentTunnel?.Name ?? "?",
                                                DeferHardwareIdentificationPackets);
                                            dev.D.SendPacket(idPacket);
                                        }
                                    }
                                }
                            }
                            else
                            {
                                dev.Remove = true;
                                //look for another device in _TempDeviceHost with the same SN
                                for (int j = 0; j < _TempDeviceHost.Count; j++)
                                {
                                    if (_TempDeviceHost[j].D.SN == dev.D.SN)
                                    {
                                        if (_TempDeviceHost[j].D.IdentificationDate < dev.D.IdentificationDate)
                                        {
                                            _TempDeviceHost[j] = dev;
                                        }

                                        dev = null;
                                        break;
                                    }
                                }
                                if (dev != null)
                                {
                                    _TempDeviceHost.Add(dev);
                                }
                            }
                        }
                        ScanRemoved = ScanRemoved || dev == null || dev.Remove;
                    }
                });
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[PENDING] Timer pending-device pass failed: {0}", ex.Message);
            }

            try
            {
                #region Remove closed (Parallel)

                if (ScanRemoved)
                {
                    DeviceHost_Pending_Slim.MyWriteLock((list) =>
                    {
                        for (int i = list.Count - 1; i >= 0; i--)
                        {
                            if (list[i].Remove)
                            {
                                list[i].Remove = false;
                                list.RemoveAt(i);
                            }
                        }
                    });
                }
                #endregion
            }

            catch
            {
            }

            #endregion

            #region Device timer

            try
            {
                Device.HardwareDeviceHost _DeviceHost = null;
                foreach (var newPending in _TempDeviceHost)
                {
                    _DeviceHost = null;
                    DeviceHost_Slim.MyReadLock(list =>
                    {
                        list.TryGetValue(newPending.D.SN, out _DeviceHost);
                    });

                    //for exists device, update ComLayer
                    if (_DeviceHost != null)
                    {
                        _DeviceHost.InitSessions(newPending.D as HardwareDeviceHost);
                        newPending.D.ReplaceComLayer(null);
                    }

                    else
                    {
                        _DeviceHost = (HardwareDeviceHost)newPending.D;
                        DeviceHost_Slim.MyWriteLock(list =>
                        {
                            list.TryAdd(_DeviceHost.SN, _DeviceHost);
                        });

                        _DeviceHost.InitSessions();
                    }
                    var _connectionEventArgs = new Events.DeviceConnectionEventArgs(_DeviceHost);
                    MainEventsBus.Fire_DeviceConnection(this, _connectionEventArgs);

                    if (!_connectionEventArgs.Handled)
                    {
                        _connectionEventArgs.Device.Disconnect();
                    }
                    else
                    {
                        //for new device, add to list

                    }
                }

                #region DeviceHost start internal timers (Parallel)

                DeviceHost_Slim.MyReadLock(list =>
                {
                    Parallel.ForEach(list, item =>
                    {
                        item.Value.Timer();
                    });
                });
                WSDeviceHost_Slim.MyReadLock(list =>
                {
                    Parallel.ForEach(list, item =>
                    {
                        item.Value.Timer();
                    });
                });
                #endregion
            }
            catch
            {
            }

            #endregion


            var t = TimerManager_DeviceHost;

            if (t != null)
            {
                t.Start();
            }
        }

        #endregion
    }
}
