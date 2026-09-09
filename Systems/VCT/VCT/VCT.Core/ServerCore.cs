using Maba.DAL.BaseDAL;
using Maba.VCT.Accessories;
using Maba.VCT.ComLayer.Com_Layer;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
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

        // Its own timer, not a counter inside the device tick: a serial rediscovery pass opens ports
        // and waits for *IDN?, and doing that on the 2s tick thread would stall every live device
        // for the duration - the same starvation a slow GPIB address already causes.
        private Timer TimerRediscover = null;
        private int _rediscoverRunning;

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
            this.MainEventsBus.DeviceConnnection += MainEventsBus_DeviceConnectionForAlerts;
            this.MainEventsBus.DeviceAlert += MainEventsBus_DeviceAlert;
            CurrentServerSettings = new Settings.VCTSettings();
        }

        /// <summary>
        /// MBA-962: forwards an alert a device's BL raised (a lost channel, typically) to the WS
        /// clients, in the same shape and through the same path as the server's own alerts.
        /// </summary>
        private void MainEventsBus_DeviceAlert(object o, Events.DeviceAlertEventArgs e)
        {
            if (e?.Device == null || string.IsNullOrEmpty(e.AlertType)) return;

            BroadcastAlertToWebSockets(e.Device, e.AlertType, e.Message, e.Channel);
        }

        /// <summary>
        /// MBA-485 AC5: when a hardware logger drops (self-disconnect or comm-loss), push a
        /// <c>CMD:"Alert"</c> (AlertType ChannelDisconnected) to every WS client so the UI can notify
        /// the calibrator. Connects are ignored here (handled by the BL-claim path).
        /// </summary>
        private void MainEventsBus_DeviceConnectionForAlerts(object o, Events.DeviceConnectionEventArgs e)
        {
            if (e?.Device is Device.HardwareDeviceHost hw && !hw.IsConnected && !string.IsNullOrEmpty(hw.SN)
                && !hw.DisconnectAlerted)
            {
                hw.DisconnectAlerted = true; // both the self-disconnect and comm-loss paths fire; alert once
                BroadcastAlertToWebSockets(hw, "ChannelDisconnected",
                    string.Format("Logger {0} disconnected - no data received", hw.SN));
            }
        }

        private void MainEventsBus_DeviceOnIncomingEvent(object o, Events.DeviceEventArgs e)
        {
            // If the event came from a Hardware device, broadcast it to all WebSocket clients
            if (e.Device is Device.HardwareDeviceHost hardwareDevice)
            {
                Libs.Trace.Tracer.Info("[ServerCore] DeviceOnIncomingEvent from SN={0}, packet={1}", hardwareDevice.SN, e.Packet?.ToString()?.Trim());
                BroadcastToWebSockets(hardwareDevice, e.Packet);
            }
            /*  Any message from the web app may announce who is signed in. The ComServer starts
                before anyone signs in and cannot read the browser's session, so this is the only
                way it learns whose loggers and channels to load. Recorded before the message is
                acted on, so a Status:"Start" that carries the address is already attributed. */
            if (e.Device is Device.WebSocketDeviceHost
                && e.Packet is Common.Protocol_Parser.WebSocketMessage.BaseMessage announced
                && !string.IsNullOrWhiteSpace(announced.Email))
            {
                if (Common.CalibratorSession.SetEmail(announced.Email))
                {
                    Libs.Trace.Tracer.Info("[ServerCore] Signed-in calibrator announced by the web app: {0}",
                        Common.CalibratorSession.Email);
                }
            }

            // If the event came from a WebSocket client with a Status:Stop command, disconnect all hardware devices
            if (e.Device is Device.WebSocketDeviceHost && e.Packet is Common.Protocol_Parser.WebSocketMessage.StatusMessage statusMsg)
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

                        // An association from the app wins; otherwise fall back to what this
                        // instrument actually measures rather than assuming temperature.
                        var wsUnits = !string.IsNullOrEmpty(wsHost.AssociatedUnits)
                            ? wsHost.AssociatedUnits
                            : HardwareBL_Settings.Read().DefaultUnitsForDeviceSN(device.SN);
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

        /// <summary>How long a scanning logger may go silent before a DataTimeout alert (MBA-485 AC5/AC6).</summary>
        private static readonly TimeSpan DataTimeout_TimeSpan = TimeSpan.FromSeconds(60);

        /// <summary>MBA-962: how long to wait between attempts to restart a silent device's BL.</summary>
        private static readonly TimeSpan Recovery_RetryInterval = TimeSpan.FromSeconds(60);

        /// <summary>
        /// MBA-962: how many times to try restarting one silent device before leaving it alone.
        /// Bounded on purpose — a device that is off, or whose cable is dead in a way the port does not
        /// report, would otherwise be re-initialized every minute for as long as the server runs, each
        /// attempt re-reading the master corrections from SQL.
        /// </summary>
        private const int Recovery_MaxAttempts = 5;

        /// <summary>
        /// The app drops an alert entirely unless EVERY field matches its regex and is non-empty
        /// (parse-alert-message.ts returns null on the first blank). A device-wide alert has no
        /// single channel and no reading, so these two carry placeholders rather than being omitted.
        /// </summary>
        private const string AlertChannelAll = "ALL";
        private const string AlertValueNone = "0";

        /// <summary>
        /// MBA-485 AC5/AC6: builds the alert line in the exact shape the web app parses.
        ///
        /// Split out from the socket write and left testable on purpose: the format is the part that
        /// breaks silently. The app matches each field with its own regex and discards the whole
        /// alert if one fails, so a stray character costs the alert with nothing logged anywhere.
        /// </summary>
        /// <param name="deviceId">Serial of the device the alert is ABOUT - see the caller.</param>
        /// <param name="loggerId">Same serial; the app carries both fields through to the UI.</param>
        /// <param name="batchId">The receiving client's run, or LIVE.</param>
        /// <param name="localTime">Local time: the app parses with date-fns into the browser's zone.</param>
        /// <param name="channel">
        /// The channel the alert is about, or null for a device-wide alert (rendered as "ALL").
        /// MBA-962: the app groups disconnect ranges by deviceId:channel and closes a range only with a
        /// DataRestored carrying the SAME channel, so a per-channel alert must name its channel and its
        /// restore must name it again — a restore sent as "ALL" leaves the channel shaded for good.
        /// </param>
        internal static string BuildAlertMessage(string deviceId, string loggerId, string batchId,
                                                string alertType, string message, DateTime localTime,
                                                string channel = null)
        {
            return string.Format(
                CultureInfo.InvariantCulture,
                "CMD:\"Alert\", DeviceID:\"{0}\", LoggerID:\"{1}\", BatchID:\"{2}\", Channel:\"{3}\", Value:\"{4}\", AlertType:\"{5}\", Message:\"{6}\", Time:\"{7}\"",
                deviceId, loggerId, batchId,
                string.IsNullOrWhiteSpace(channel) ? AlertChannelAll : channel,
                AlertValueNone, alertType, message,
                // InvariantCulture matters: the app parses 'MM/dd/yyyy HH:mm:ss', and the '/' in a
                // custom format string is the CULTURE's date separator, not a literal. A server whose
                // locale uses '.' would emit a timestamp the app cannot parse, and the alert would be
                // dropped whole.
                localTime.ToString("MM/dd/yyyy HH:mm:ss", CultureInfo.InvariantCulture));
        }

        /// <summary>
        /// MBA-485 AC5/AC6: sends a <c>CMD:"Alert"</c> about <paramref name="device"/> to every WS client.
        ///
        /// DeviceID and LoggerID name the device that actually failed, NOT the receiving client's
        /// sensor association. Those are different namespaces - an association's LoggerId is matched
        /// against HardwareBL_Settings.Masters, never against a serial - so using the association
        /// labelled every client's alert with that client's own logger, whichever device had really
        /// dropped. Invisible with one logger; with several it names the wrong one every time.
        ///
        /// Broadcasting to all clients is deliberate and safe: the app does not filter alerts by
        /// DeviceID (BackgroundDataProcessor adds every parsed alert, and group-alerts groups by
        /// channel and type), so the id is a label, and a truthful serial beats a wrong association.
        /// </summary>
        [ExcludeFromCodeCoverage]
        private void BroadcastAlertToWebSockets(Device.HardwareDeviceHost device, string alertType, string message,
                                                string channel = null)
        {
            if (device == null) return;

            WSDeviceHost_Slim.MyReadLock(list =>
            {
                foreach (var wsHost in list.Values)
                {
                    try
                    {
                        var com = wsHost.InternalComLayer;
                        if (com == null || !com.IsConnected) continue;

                        // The batch IS the receiving client's, unlike the ids above: it identifies the
                        // run the operator is looking at, which is what the alert has to appear inside.
                        var batchId = !string.IsNullOrEmpty(wsHost.AssociatedBatchId) ? wsHost.AssociatedBatchId : "LIVE";

                        var wsMessage = BuildAlertMessage(device.SN, device.SN, batchId, alertType, message, DateTime.Now, channel);

                        com.SendString(wsMessage);
                        Libs.Trace.Tracer.Info("[WS TX ALERT] {0}", wsMessage);
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info("[WS TX ALERT] Failed to broadcast alert: {0}", ex.Message);
                    }
                }
            });
        }

        /// <summary>
        /// MBA-485 AC5/AC6: per-device watchdog run on the server timer. Once a logger has started producing
        /// data, if it goes silent past <see cref="DataTimeout_TimeSpan"/> a DataTimeout alert is sent (once);
        /// when data resumes a DataRestored alert is sent. Keyed per device SN so multiple loggers are tracked
        /// independently and their alerts are not mixed.
        /// </summary>
        [ExcludeFromCodeCoverage]
        private void CheckDataTimeouts(DateTime nowUtc)
        {
            // MBA-962: devices to restart are collected under the lock and restarted after it is
            // released. ReinitializeBL runs the BL's OnCreateStates, which re-reads the master
            // corrections from SQL - holding the device read lock across that would stall the tick.
            var toRecover = new System.Collections.Generic.List<Device.HardwareDeviceHost>();

            DeviceHost_Slim.MyReadLock(list =>
            {
                foreach (var device in list.Values)
                {
                    if (device == null) continue;

                    switch (EvaluateDataWatchdog(device.IsConnected, device.LastMeasurementUtc,
                                                 device.DataTimedOut, nowUtc, DataTimeout_TimeSpan))
                    {
                        case DataWatchdogAction.Timeout:
                            device.DataTimedOut = true;
                            BroadcastAlertToWebSockets(device, "DataTimeout",
                                string.Format(CultureInfo.InvariantCulture,
                                              "No data received for {0} seconds",
                                              (int)DataTimeout_TimeSpan.TotalSeconds));
                            break;

                        case DataWatchdogAction.Restored:
                            device.DataTimedOut = false;
                            device.RecoveryAttempts = 0;
                            device.LastRecoveryAttemptUtc = null;
                            BroadcastAlertToWebSockets(device, "DataRestored", "Data transmission resumed");
                            break;
                    }

                    if (ShouldAttemptRecovery(device.IsConnected, device.DataTimedOut,
                                              device.LastRecoveryAttemptUtc, device.RecoveryAttempts,
                                              Recovery_MaxAttempts, nowUtc, Recovery_RetryInterval))
                    {
                        device.RecoveryAttempts++;
                        device.LastRecoveryAttemptUtc = nowUtc;
                        toRecover.Add(device);
                    }
                }
            });

            foreach (var device in toRecover)
            {
                try
                {
                    device.ReinitializeBL(string.Format(CultureInfo.InvariantCulture,
                        "silent for over {0}s - power-cycle recovery attempt {1}/{2}",
                        (int)DataTimeout_TimeSpan.TotalSeconds, device.RecoveryAttempts, Recovery_MaxAttempts));
                }
                catch (Exception ex)
                {
                    // A failed restart must not take the server timer down with it: the device is
                    // already not producing data, and the next attempt is a minute away.
                    Libs.Trace.Tracer.Info("[RECOVERY] SN={0} re-initialization threw: {1}", device.SN, ex.Message);
                }
            }
        }

        /// <summary>
        /// MBA-962 (power-cycle recovery) — whether to restart one silent device's BL on this tick.
        /// Pure, for the same reason <see cref="EvaluateDataWatchdog"/> is: the interesting part is
        /// the edges and the bound, and neither is reachable in a test that needs a real instrument.
        ///
        /// A power-cycled logger is the case this exists for. It comes back with its scan
        /// configuration gone while the serial port stayed open, so it reports connected, produces
        /// nothing, and no discovery pass can find it because the port is still held.
        /// </summary>
        /// <param name="isConnected">A dropped link is a different failure with a different alert.</param>
        /// <param name="timedOut">Only a device the watchdog has already declared silent is restarted.</param>
        /// <param name="lastAttemptUtc">Null when no attempt has been made since the device last had data.</param>
        internal static bool ShouldAttemptRecovery(bool isConnected, bool timedOut, DateTime? lastAttemptUtc,
                                                   int attempts, int maxAttempts, DateTime nowUtc,
                                                   TimeSpan retryInterval)
        {
            if (!isConnected) return false;
            if (!timedOut) return false;
            if (attempts >= maxAttempts) return false;

            // First attempt goes out on the same tick the timeout was declared: a power cycle is over
            // long before the 60s watchdog fires, so there is nothing to wait for.
            if (lastAttemptUtc == null) return true;

            return nowUtc - lastAttemptUtc.Value >= retryInterval;
        }

        /// <summary>What the data watchdog decided for one device on one tick.</summary>
        internal enum DataWatchdogAction
        {
            None,
            Timeout,
            Restored,
        }

        /// <summary>
        /// MBA-485 AC5/AC6 — the watchdog decision for a single device, split out from the loop that
        /// holds the device lock and writes to sockets. The decision is where the edges live, and the
        /// edges are what break: alerting twice for one silence, or never announcing the recovery.
        /// Keeping it pure means those can be tested without a device, a socket or a clock.
        /// </summary>
        /// <param name="isConnected">A dropped link is the ChannelDisconnected alert's business.</param>
        /// <param name="lastMeasurementUtc">Null until the device has produced a reading.</param>
        /// <param name="alreadyTimedOut">The device's current watchdog state, for edge detection.</param>
        internal static DataWatchdogAction EvaluateDataWatchdog(bool isConnected, DateTime? lastMeasurementUtc,
                                                               bool alreadyTimedOut, DateTime nowUtc, TimeSpan limit)
        {
            // A disconnected device already produces ChannelDisconnected. Reporting silence as well
            // would put two alerts in the UI for one event.
            if (!isConnected) return DataWatchdogAction.None;

            // Never measured: the device is idle, not silent. Watching from here would fire a timeout
            // against a device that has simply not been asked to scan yet.
            if (lastMeasurementUtc == null) return DataWatchdogAction.None;

            var silent = nowUtc - lastMeasurementUtc.Value > limit;

            if (silent) return alreadyTimedOut ? DataWatchdogAction.None : DataWatchdogAction.Timeout;

            return alreadyTimedOut ? DataWatchdogAction.Restored : DataWatchdogAction.None;
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

            Device_MainSockets = new List<Socket>();

            Libs.Trace.Tracer.Info($"[STARTUP] Configured tunnels: {CurrentServerSettings.Tunnels.Length}");

            var tunnelsToOpen = new List<ComLayer.Tunnel>(CurrentServerSettings.Tunnels);

            if (CurrentServerSettings.AutoDiscoverTransports)
            {
                tunnelsToOpen.AddRange(DiscoverTransportTunnels(CurrentServerSettings.Tunnels));
            }

            int serialCount = 0;
            int tcpCount = 0;

            foreach (var t in tunnelsToOpen)
            {
                if (!string.IsNullOrWhiteSpace(t.VisaResource))
                {
                    // VISA tunnel: open a VisaCom on the configured resource (needs a VISA runtime).
                    Libs.Trace.Tracer.Info($"[STARTUP] Opening VISA resource {t.VisaResource}...");
                    try
                    {
                        var visa = new ComLayer.VisaCom(t.VisaResource, t) { TimeoutMs = t.VisaTimeoutMs };
                        AddDevice_Pending_ComLayer(visa);
                        visa.Open();
                        Libs.Trace.Tracer.Info($"[STARTUP] VISA resource {visa.ResolvedResourceName} opened OK");
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info($"[STARTUP] FAILED to open VISA resource {t.VisaResource}: {ex.Message}");
                    }
                }
                else if (t.GpibPrimaryAddress >= 0)
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
                        // Exclude ports another tunnel claims by name: DetectUsbToSerialPort matches
                        // on "Prolific"/"FTDI"/"CH340"/..., so without this an AUTO tunnel would grab
                        // the adapter a named tunnel already owns and open it at the wrong baud rate
                        // (the PRODIGIT 3111 is a Prolific adapter that needs 115200, not the 9600 the
                        // AUTO tunnel is configured for).
                        var claimedPorts = CurrentServerSettings.Tunnels
                            .Where(other => !string.IsNullOrWhiteSpace(other.SerialPortName)
                                         && !string.Equals(other.SerialPortName, "AUTO", StringComparison.OrdinalIgnoreCase))
                            .Select(other => other.SerialPortName.Trim())
                            .ToList();

                        var detectedPort = DetectUsbToSerialPort(claimedPorts);
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

            if (CurrentServerSettings.AutoDiscoverTransports && CurrentServerSettings.RediscoverIntervalSeconds > 0)
            {
                TimerRediscover = new Timer();
                TimerRediscover.Interval = CurrentServerSettings.RediscoverIntervalSeconds * 1000;
                TimerRediscover.Elapsed += TimerRediscover_Elapsed;
                TimerRediscover.AutoReset = true;
                TimerRediscover.Start();
                Libs.Trace.Tracer.Info(
                    $"[STARTUP] Rediscovery timer started (every {CurrentServerSettings.RediscoverIntervalSeconds}s) - an instrument plugged in later will be picked up without a restart.");
            }
            else
            {
                Libs.Trace.Tracer.Info("[STARTUP] Rediscovery is off; an instrument plugged in after startup needs a service restart.");
            }

            #endregion

            #region WebSocket
            Libs.Trace.Tracer.Info($"[STARTUP] Initializing WebSocket on {WebSocketAddress}...");
            WebSocketInit();
            #endregion

            #region DB connector
            /* VCT.json names the connection string "KyulanSyncDB", but the station's .exe.config
               ships it as REMOTE_DATABASE_URL - the name the web app and the rest of the host use.
               Looking up only GeneralDBName returns null, and BaseDALConnector dereferences it, so
               a perfectly healthy station reported "DB connection FAILED ... Object reference not
               set" and printed "DB: not connected" in the startup summary. That summary is what an
               installer checks to confirm the connection string points where it should, so it has
               to tell the truth. Program.GetSqlConnectionString() already falls back this way. */
            var dbSectionName = ResolveDbSectionName(
                CurrentServerSettings.GeneralDBName,
                System.Configuration.ConfigurationManager.ConnectionStrings);
            if (dbSectionName == null)
            {
                Libs.Trace.Tracer.Info(
                    $"[STARTUP] DB not configured (non-fatal): no connectionStrings entry named " +
                    $"'{CurrentServerSettings.GeneralDBName}' or 'REMOTE_DATABASE_URL' in the .exe.config.");
            }
            else
            {
                try
                {
                    var candidate = new MSSqlServer(dbSectionName);
                    await candidate.OpenAsync();
                    // Only now is it genuinely connected; assigning before the open made the
                    // summary claim "connected" whenever Open() itself failed.
                    connector = candidate;
                    Libs.Trace.Tracer.Info($"[STARTUP] DB connected OK (connectionStrings/{dbSectionName}).");
                }
                catch (Exception dbEx)
                {
                    Libs.Trace.Tracer.Info(
                        $"[STARTUP] DB connection FAILED (non-fatal) using connectionStrings/{dbSectionName}: {dbEx.Message}");
                }
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
            // Unique key per connection. Previously every client was registered under the constant
            // key "Eliran", so a second connection (e.g. the /ws/rfid client that connects at startup,
            // or a second browser tab) overwrote the first, and either socket's disconnect removed the
            // survivor from the broadcast list — the browser would silently stop receiving LoggerData.
            string wsKey = Guid.NewGuid().ToString("N");
            try
            {
                wsc = new WebSocketCom(webSocket);
                wsdh = new WebSocketDeviceHost(MainEventsBus, wsc, wsKey);
                WSDeviceHost_Slim.MyWriteLock(list =>
                {
                    list[wsKey] = wsdh;
                });
                MainEventsBus.Fire_WebSocketConnection(this, new Events.DeviceConnectionEventArgs(wsdh));
                Libs.Trace.Tracer.Info("[WS] Client connected (key={0}, path={1}, state={2})",
                    wsKey, ctx.Request.Url.AbsolutePath, webSocket.State.ToString());

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
                    list.TryRemove(wsKey, out _);
                });
                Libs.Trace.Tracer.Info("[WS] Client session ended (key={0}, state={1})", wsKey, webSocket?.State.ToString());
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

            if (TimerRediscover != null)
            {
                TimerRediscover.Elapsed -= TimerRediscover_Elapsed;
                TimerRediscover.Stop();
                TimerRediscover = null;
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

        #endregion

        #region Private methods

        /// <summary>
        /// Opens one discovered transport and hands it to the pending list. Returns false if it
        /// could not be opened, which for a rediscovery pass is the normal answer for a port
        /// something else already holds.
        /// </summary>
        [ExcludeFromCodeCoverage]
        private bool OpenDiscoveredTunnel(ComLayer.Tunnel t, string phase)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(t.VisaResource))
                {
                    var visa = new ComLayer.VisaCom(t.VisaResource, t) { TimeoutMs = t.VisaTimeoutMs };
                    AddDevice_Pending_ComLayer(visa);
                    visa.Open();
                    Libs.Trace.Tracer.Info("[{0}] VISA resource {1} opened OK", phase, visa.ResolvedResourceName);
                }
                else if (t.GpibPrimaryAddress >= 0)
                {
                    var gpib = new ComLayer.GpibCom(t.GpibPrimaryAddress, t.GpibBoardIndex, t);
                    AddDevice_Pending_ComLayer(gpib);
                    gpib.Open();
                    Libs.Trace.Tracer.Info("[{0}] GPIB address {1} opened OK", phase, t.GpibPrimaryAddress);
                }
                else if (!string.IsNullOrEmpty(t.SerialPortName))
                {
                    var serialCom = new ComLayer.SerialCom(t.SerialPortName, t.SerialBaudRate, t.SerialTimeout, t);
                    AddDevice_Pending_ComLayer(serialCom);
                    serialCom.Open();
                    Libs.Trace.Tracer.Info("[{0}] Serial port {1} opened OK ({2} baud)", phase, t.SerialPortName, t.SerialBaudRate);
                }
                else
                {
                    return false;
                }

                return true;
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[{0}] FAILED to open {1}: {2}", phase, t.Name ?? "?", ex.Message);
                return false;
            }
        }

        /// <summary>
        /// The transports we are already holding, as a tunnel array shaped like the configured one,
        /// so <see cref="DiscoverTransportTunnels"/> can treat them as claimed and leave them alone.
        /// <para>
        /// A serial port we hold would fail to reopen anyway - Windows refuses a second open, even
        /// from the same process - so for serial this only saves a pointless probe. For GPIB and
        /// VISA it is load-bearing: enumeration does not open anything, so without this a
        /// rediscovery pass would add a second tunnel for an address that is already live.
        /// </para>
        /// </summary>
        [ExcludeFromCodeCoverage]
        private ComLayer.Tunnel[] CurrentlyHeldTransports()
        {
            var held = new List<ComLayer.Tunnel>();

            Action<ComLayer.IComLayer> take = (layer) =>
            {
                var t = layer?.ParentTunnel;
                if (t != null) held.Add(t);
            };

            DeviceHost_Pending_Slim.MyReadLock((list) =>
            {
                foreach (var pending in list) take(pending.D?.InternalComLayer);
            });

            DeviceHost_Slim.MyReadLock((dict) =>
            {
                foreach (var host in dict.Values) take(host?.InternalComLayer);
            });

            return held.ToArray();
        }

        /// <summary>
        /// Looks for instruments that appeared since startup and brings them in. This is what makes
        /// unplugging a logger and plugging it back in recoverable without restarting the service
        /// (MBA-962 item 4).
        /// </summary>
        [ExcludeFromCodeCoverage]
        private void RediscoverTick()
        {
            var held = CurrentlyHeldTransports();

            // The configured tunnels stay claimed too, or a static tunnel that is merely closed at
            // this instant would be rediscovered and opened a second time.
            var claimed = new List<ComLayer.Tunnel>(CurrentServerSettings.Tunnels);
            claimed.AddRange(held);

            var found = DiscoverTransportTunnels(claimed.ToArray(), "REDISCOVER");
            if (found.Count == 0) return;

            Libs.Trace.Tracer.Info("[REDISCOVER] {0} new transport(s) appeared since startup.", found.Count);
            foreach (var t in found) OpenDiscoveredTunnel(t, "REDISCOVER");
        }

        [ExcludeFromCodeCoverage]
        private void TimerRediscover_Elapsed(object sender, ElapsedEventArgs e)
        {
            // Same one-at-a-time guard as the device tick: a serial pass opens ports and waits for
            // *IDN?, and two overlapping passes would fight over the same candidate port.
            if (System.Threading.Interlocked.CompareExchange(ref _rediscoverRunning, 1, 0) != 0)
                return;

            try
            {
                RediscoverTick();
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[REDISCOVER] pass failed (will retry): {0}", ex.Message);
            }
            finally
            {
                System.Threading.Interlocked.Exchange(ref _rediscoverRunning, 0);
            }
        }

        /// <summary>
        /// Turns everything <see cref="ComLayer.TransportDiscovery"/> can find into tunnels, skipping
        /// anything the static configuration already covers.
        /// <para>
        /// A configured tunnel always wins: its VISA resource, GPIB address or serial port is left to
        /// it, so discovery can never open a second link to the same instrument.
        /// </para>
        /// </summary>
        [ExcludeFromCodeCoverage]
        private List<ComLayer.Tunnel> DiscoverTransportTunnels(ComLayer.Tunnel[] configured)
        {
            return DiscoverTransportTunnels(configured, "STARTUP");
        }

        /// <summary>
        /// As above, with the phase named in the log so a startup pass and a rediscovery pass can be
        /// told apart in `server.log` — they do the same work for entirely different reasons.
        /// </summary>
        [ExcludeFromCodeCoverage]
        private List<ComLayer.Tunnel> DiscoverTransportTunnels(ComLayer.Tunnel[] configured, string phase)
        {
            var discovered = new List<ComLayer.Tunnel>();

            try
            {
                var anyVisaConfigured = configured.Any(t => !string.IsNullOrWhiteSpace(t.VisaResource));
                var claimedGpib = new HashSet<int>(
                    configured.Where(t => t.GpibPrimaryAddress >= 0).Select(t => t.GpibPrimaryAddress));
                var claimedSerial = configured
                    .Where(t => !string.IsNullOrWhiteSpace(t.SerialPortName)
                             && !string.Equals(t.SerialPortName, "AUTO", StringComparison.OrdinalIgnoreCase))
                    .Select(t => t.SerialPortName.Trim())
                    .ToList();

                Libs.Trace.Tracer.Info("[{0}] Discovering attached instruments...", phase);

                // A configured VISA entry may be a find expression rather than a literal resource, so
                // matching names is not reliable. If any USB tunnel is configured at all, that
                // configuration stands and USB discovery stays out of the way.
                if (!anyVisaConfigured)
                {
                    foreach (var usb in ComLayer.TransportDiscovery.DiscoverUsb())
                        discovered.Add(new ComLayer.Tunnel { Name = usb.Name, VisaResource = usb.VisaResource });
                }

                foreach (var gpib in ComLayer.TransportDiscovery.DiscoverGpib())
                {
                    if (claimedGpib.Contains(gpib.GpibPrimaryAddress)) continue;
                    discovered.Add(new ComLayer.Tunnel { Name = gpib.Name, GpibPrimaryAddress = gpib.GpibPrimaryAddress });
                }

                foreach (var serial in ComLayer.TransportDiscovery.DiscoverSerial(claimedSerial, ListProbeableSerialPorts()))
                {
                    discovered.Add(new ComLayer.Tunnel
                    {
                        Name = serial.Name,
                        SerialPortName = serial.SerialPortName,
                        SerialBaudRate = serial.SerialBaudRate,
                        SerialTimeout = 100
                    });
                }

                Libs.Trace.Tracer.Info("[{0}] Discovery added {1} tunnel(s).", phase, discovered.Count);
            }
            catch (Exception ex)
            {
                // Discovery is an optimisation, never a prerequisite: a failure here must not stop the
                // configured tunnels from opening.
                Libs.Trace.Tracer.Info("[{0}] Transport discovery failed (continuing with configured tunnels): {1}", phase, ex.Message);
            }

            return discovered;
        }

        /// <summary>
        /// The name of the connectionStrings entry to open the startup DB check with: the one
        /// VCT.json asks for, else REMOTE_DATABASE_URL, else null when neither is configured.
        /// Returning the name rather than the string keeps the connection string itself - which
        /// carries a password - out of every log line and exception message.
        /// </summary>
        /// <remarks>
        /// Takes the collection rather than reading ConfigurationManager itself so a test can hand
        /// it an empty one - the "nothing is configured" case is otherwise unreachable, because the
        /// test host's own App.config always defines REMOTE_DATABASE_URL.
        /// </remarks>
        internal static string ResolveDbSectionName(
            string preferredName, System.Configuration.ConnectionStringSettingsCollection configured)
        {
            if (!string.IsNullOrWhiteSpace(preferredName) && configured[preferredName] != null)
            {
                return preferredName;
            }

            return configured["REMOTE_DATABASE_URL"] != null ? "REMOTE_DATABASE_URL" : null;
        }

        /// <summary>
        /// The COM ports worth probing for an instrument: everything the OS reports except Bluetooth
        /// serial links, which are never instruments and can block for many seconds on open - probing
        /// the two on this bench stretched startup from a few seconds to 46.
        /// Returns null when the ports cannot be classified, which leaves discovery to probe them all.
        /// </summary>
        [ExcludeFromCodeCoverage]
        private List<string> ListProbeableSerialPorts()
        {
            try
            {
                var probeable = new List<string>();
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'"))
                {
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (string.IsNullOrEmpty(name)) continue;

                        var match = System.Text.RegularExpressions.Regex.Match(name, @"\(COM(\d+)\)");
                        if (!match.Success) continue;

                        if (name.IndexOf("Bluetooth", StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            Libs.Trace.Tracer.Info("[Discovery] COM{0} is a Bluetooth link - not probed.", match.Groups[1].Value);
                            continue;
                        }

                        probeable.Add("COM" + match.Groups[1].Value);
                    }
                }
                return probeable;
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[Discovery] Could not classify serial ports ({0}); probing all of them.", ex.Message);
                return null;
            }
        }

        /// <summary>Device-name fragments that mark a COM port as a USB-to-serial adapter.</summary>
        internal static readonly string[] UsbToSerialKeywords =
            { "USB-to-Serial", "USB Serial", "FTDI", "CH340", "CP210", "Prolific" };

        /// <summary>
        /// Chooses the port an AUTO serial tunnel should open, given every COM port the OS reported.
        /// <para>
        /// Pure decision logic, deliberately separated from the WMI query in
        /// <see cref="DetectUsbToSerialPort"/> so it can be tested without hardware. The order is:
        /// drop anything another tunnel claims by name, prefer a USB-to-serial adapter, then fall back
        /// to the first non-Bluetooth port.
        /// </para>
        /// <para>
        /// The exclusion is what keeps AUTO off a port that already belongs to someone: the keyword
        /// list matches "Prolific", so without it the AUTO tunnel would take the PRODIGIT 3111's
        /// adapter and open it at its own 9600 instead of the load's 115200.
        /// </para>
        /// </summary>
        /// <param name="ports">Reported ports as portName -> device name, in the order the OS listed them.</param>
        /// <param name="excludePorts">Ports another tunnel claims by name; never returned.</param>
        /// <returns>The port to open, or null when nothing is suitable.</returns>
        internal static string SelectAutoSerialPort(
            IEnumerable<KeyValuePair<string, string>> ports,
            IEnumerable<string> excludePorts)
        {
            if (ports == null)
                return null;

            var excluded = excludePorts != null
                ? new HashSet<string>(excludePorts.Where(p => !string.IsNullOrWhiteSpace(p)).Select(p => p.Trim()),
                                      StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            var candidates = ports
                .Where(p => !string.IsNullOrWhiteSpace(p.Key) && !excluded.Contains(p.Key.Trim()))
                .ToList();

            foreach (var port in candidates)
            {
                var name = port.Value ?? "";
                if (UsbToSerialKeywords.Any(k => name.IndexOf(k, StringComparison.OrdinalIgnoreCase) >= 0))
                    return port.Key;
            }

            foreach (var port in candidates)
            {
                var name = port.Value ?? "";
                if (name.IndexOf("Bluetooth", StringComparison.OrdinalIgnoreCase) < 0)
                    return port.Key;
            }

            return null;
        }

        /// <summary>
        /// Auto-detects the COM port for an AUTO serial tunnel: asks WMI which ports exist, then
        /// applies <see cref="SelectAutoSerialPort"/>. Only the WMI query lives here — the choice
        /// itself is pure and unit-tested.
        /// </summary>
        /// <param name="excludePorts">Ports another tunnel already claims by name; never returned.</param>
        [ExcludeFromCodeCoverage]
        private string DetectUsbToSerialPort(List<string> excludePorts = null)
        {
            try
            {
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'"))
                {
                    var ports = new List<KeyValuePair<string, string>>(); // portName -> device name
                    foreach (ManagementObject obj in searcher.Get())
                    {
                        var name = obj["Name"]?.ToString();
                        if (string.IsNullOrEmpty(name)) continue;

                        // Extract COM port number from name like "Prolific USB-to-Serial Comm Port (COM9)"
                        var match = System.Text.RegularExpressions.Regex.Match(name, @"\(COM(\d+)\)");
                        if (!match.Success) continue;

                        var portName = "COM" + match.Groups[1].Value;
                        ports.Add(new KeyValuePair<string, string>(portName, name));
                        Libs.Trace.Tracer.Info("[AutoDetect] Found: {0} = {1}", portName, name);
                    }

                    if (excludePorts != null && excludePorts.Count > 0)
                    {
                        Libs.Trace.Tracer.Info("[AutoDetect] Excluded (claimed by a named tunnel): {0}",
                            string.Join(", ", excludePorts));
                    }

                    var selected = SelectAutoSerialPort(ports, excludePorts);
                    if (selected != null)
                    {
                        var deviceName = ports.First(p => p.Key == selected).Value;
                        Libs.Trace.Tracer.Info("[AutoDetect] Selected: {0} ({1})", selected, deviceName);
                    }
                    return selected;
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

        /// <summary>0 when no device tick is running, 1 while one is. See TimerManager_Device_Elapsed.</summary>
        private int _deviceTickRunning;

        /// <summary>Long-running timer orchestration; validated in integration/manual runs.</summary>
        [ExcludeFromCodeCoverage]
        void TimerManager_Device_Elapsed(object sender, ElapsedEventArgs e)
        {
            if (TimerManager_DeviceHost == null)
                return;

            // One tick at a time. System.Timers.Timer fires again on a new thread whether or not the
            // previous callback has finished, and _TempDeviceHost is a shared field that each tick
            // Clear()s at the start and reads at the end. Overlapping ticks therefore raced: one tick
            // queued an identified device for promotion, a second cleared the list before the first
            // got to it, and the device was re-queued forever and never promoted - silently, since
            // nothing threw. A tick gets slow enough for this whenever a tunnel is answering slowly,
            // e.g. a GPIB address with no listener burning its timeout on every pass.
            if (System.Threading.Interlocked.CompareExchange(ref _deviceTickRunning, 1, 0) != 0)
            {
                Libs.Trace.Tracer.Info("[PENDING] Previous device tick still running - skipping this one.");
                return;
            }

            try
            {
                DeviceTick();
            }
            finally
            {
                System.Threading.Interlocked.Exchange(ref _deviceTickRunning, 0);
            }
        }

        /// <summary>The device timer's actual work. Only ever entered by one thread at a time.</summary>
        [ExcludeFromCodeCoverage]
        private void DeviceTick()
        {
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
                            Libs.Trace.Tracer.Info(
                                "[PENDING] Dropping pending device (tunnel={0}, SN={1}): its link reports disconnected.",
                                dev.D.InternalComLayer?.ParentTunnel?.Name ?? "?",
                                dev.D.SN ?? "unset");
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
                        // No BL core claimed it. Say so: otherwise an SN that matches no
                        // DeviceIdToken - or a module missing from ComServerSettings.Modules - looks
                        // exactly like a device that answered *IDN? and then silently went away.
                        Libs.Trace.Tracer.Info(
                            "[PENDING] No BL module claimed SN='{0}' (tunnel={1}) - disconnecting it. " +
                            "Check the BLCore DeviceIdToken against this SN, and that the module is listed " +
                            "in Settings/ComServerSettings.json.",
                            _DeviceHost.SN,
                            _DeviceHost.InternalComLayer?.ParentTunnel?.Name ?? "?");
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

                // MBA-485 AC5/AC6: per-device data-timeout / restore watchdog.
                CheckDataTimeouts(NowTime);
                #endregion
            }
            catch (Exception ex)
            {
                // Was a bare catch: a device could answer *IDN?, fail to promote, and vanish without
                // a single line of explanation. Whatever goes wrong here, say what it was.
                Libs.Trace.Tracer.Info("[PENDING] Device promotion pass failed: {0}: {1}",
                    ex.GetType().Name, ex.Message);
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
