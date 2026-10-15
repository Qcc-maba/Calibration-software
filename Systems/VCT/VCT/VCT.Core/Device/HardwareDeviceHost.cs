using Maba.VCT.ComLayer;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device
{

    /// <summary>
    /// Hosts ONE physical instrument: wraps its <see cref="ComLayer.IComLayer"/>, cuts the incoming
    /// bytes into packets via the protocol parser, derives the serial number from the identification
    /// reply, routes each packet to the waiting <see cref="Sessions.BaseSession"/>, and owns the
    /// device's <see cref="IDeviceBL"/>. Measurements leave through BroadcastAllMeasurements.
    /// </summary>
    public class HardwareDeviceHost : IDeviceHost
    {
        #region Members

        private Events.EventsBus MainEventsBus = null;
        private HydraProtocolParser ProtocolParser = null;

        #endregion

        #region Properties

        public IDeviceBL BL { get; set; }
        public DateTime IdentificationDate { get; set; }

        public DeviceSettings DeviceSettings { get; internal set; }

        public ComLayer.IComLayer InternalComLayer { get; private set; }

        //Identity
        public string SN { get; private set; }

        public bool IsConnected
        {
            get
            {
                var com = InternalComLayer;
                return com != null && com.IsConnected;
            }
        }


        #endregion

        #region Session members

        private Sessions.BaseSession[] Sessions = null;

        private Sessions.GetSetTimeSession _SetGetTimeSession;
        private Sessions.InitSystemSession _InitSystemSession;
        private Sessions.RateSession _RateSession;
        private Sessions.InitChannelsSession _InitChannelsSession;
        private Sessions.LogsSession _LogsSession;

        //private Sessions.FormatSession _FormatSession;
        //private Sessions.ResetSession _ResetSession;


        #endregion

        #region ctor

        public HardwareDeviceHost(Events.EventsBus bus, ComLayer.IComLayer comLayer, DeviceSettings deviceSettings)
        {
            MainEventsBus = bus;
            this.DeviceSettings = deviceSettings;
            ReplaceComLayer(comLayer);

            Libs.Trace.Tracer.Info($"New Connection ({comLayer.Title})");


            ProtocolParser = new Common.HydraProtocolParser()
            {
                OnPacket = handlePacket
            };
        }

        #endregion

        #region Events

        public event Common.PacketDelegate PacketReceived; //PacketEventArgs
        public event Common.PacketDelegate PacketSent;     //PacketEventArgs 

        #endregion

        #region public methods

        internal void InitSessions(HardwareDeviceHost device = null)
        {
            if (Sessions == null)
            {
                Sessions = new Sessions.BaseSession[]
                {
                    _InitSystemSession= new Sessions.InitSystemSession(this),
                    _SetGetTimeSession = new Sessions.GetSetTimeSession(this),
                    _RateSession=new Sessions.RateSession(this),
                    _InitChannelsSession=new Sessions.InitChannelsSession(this),
                    _LogsSession= new Sessions.LogsSession(this),
                };
            }
            else if (device != null)
            {
                // MBA-967: a known device back on a new link starts a new conversation. A request
                // still in flight was sent on the old link and its reply is never coming; left in
                // place it takes the new link's replies instead. On 2026-10-08 the poll's LOG_COUNT?
                // swallowed every reply of the re-init ("HandlePacket error in session 4: Input string
                // was not in a correct format", 19 times). ReinitializeBL clears them the same way.
                for (int i = 0; i < Sessions.Length; i++)
                {
                    Sessions[i].OnDisconnect();
                }
            }
            if (device != null)
            {
                var previous = InternalComLayer;
                ReplaceComLayer(device.InternalComLayer);

                // MBA-967: the old link used to be dropped without being closed, which leaves a
                // serial handle for the finalizer to close at some random later moment. Only a dead
                // one is closed here. A live one is another link to an instrument with the same SN,
                // and closing it would just let the next rediscovery find it and swap back - so it is
                // left open on purpose, and its port stays locked until the service restarts. That is
                // logged, because nothing else would show it: with the AUTO port claimed it should be
                // rare, and the line says whether it is.
                if (previous != null && !ReferenceEquals(previous, InternalComLayer))
                {
                    if (previous.IsConnected)
                    {
                        Libs.Trace.Tracer.Info("[LINK] SN={0}: replaced by a new live link on {1}; the old live link on {2} is left open on purpose, and its port stays locked until the service restarts.",
                            SN, InternalComLayer?.Title, previous.Title);
                    }
                    else
                    {
                        CloseQuietly(previous);
                    }
                }
            }
            OnConnection();
        }

        /// <summary>
        /// MBA-967: closes a link whose connection has died underneath it, and disconnects this
        /// device from it - sessions cleared, the BL told, a disconnect alert raised - exactly as if
        /// the link had reported closing. A dead USB-serial link never reports it: .NET's
        /// <c>SerialPort.IsOpen</c> just turns false, so until this ran the device sat with a dead
        /// link indefinitely.
        /// </summary>
        /// <returns>False when there is nothing to do: no link, or a live one.</returns>
        public bool ReleaseDeadLink()
        {
            var com = InternalComLayer;
            if (com == null || com.IsConnected) return false;

            Libs.Trace.Tracer.Info("[LINK] SN={0}: {1} no longer reports open - closing it so the port can be found again.",
                SN, com.Title);

            CloseQuietly(com);

            // SerialCom.Close raises LayerClosed, which disconnects us (_executer_Destroy). A layer
            // that closes without raising it is detached here instead, with the same outcome.
            if (ReferenceEquals(InternalComLayer, com))
            {
                OnDisconnection();
                _executer_Destroy(com);
            }
            return true;
        }

        private static void CloseQuietly(ComLayer.IComLayer com)
        {
            try
            {
                com.Close();
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info("[LINK] Closing {0}: {1}", com.Title, ex.Message);
            }
        }
        public void ReplaceComLayer(ComLayer.IComLayer comLayer)
        {
            //destroy old
            _executer_Destroy(InternalComLayer);

            //get new (if any. for Pending DeviceHost we kill them by ReplaceComLayer(null))
            if (comLayer != null)
            {
                InternalComLayer = comLayer;
                InternalComLayer.DataReceived += _executer_DataReceived;
                InternalComLayer.LayerClosed += _executer_Destroy;
            }
        }
        public void SendPacket(Common.IPacket p)
        {
            HardwarePacket pac = (HardwarePacket)p;


            var _com = InternalComLayer;

            if (IsConnected && _com != null)
            {
                //change TransactionId when it's out original Common.Packet

                Libs.Trace.Tracer.Info("PACKET <TX> " + pac.ToString());

                //_com.SendBytes(p.ToBytes());
                _com.SendString(pac.Command);
                if (PacketSent != null)
                {
                    PacketSent(this, new Common.PacketEventArgs(pac));
                }

            }
        }
        public void Disconnect()
        {
            if (!IsConnected)
                return;

            Libs.Trace.Tracer.Info(true, $"#{SN} Self Disconnection");

            var com = this.InternalComLayer;
            com.Close();
            _executer_Destroy();
            MainEventsBus.Fire_DeviceConnection(this, new Events.DeviceConnectionEventArgs(this));

            if (BL != null)
            {
                BL.OnConnection(false);
            }
        }
        public void Timer()
        {
            if (Sessions != null)
            {
                for (int i = 0; i < Sessions.Length; i++)
                {
                    Sessions[i].Timer();
                }
            }
            if (BL != null)
            {
                BL.OnTimer();
                //Libs.Trace.Tracer.Info(true, $"Timer: {DateTime.Now}");

            }
        }

        #endregion

        #region API Remote Requests

        #region Init System
        public Task<Common.API.RemoteProtocolService.InitSystemResponse> Reset(Common.API.RemoteProtocolService.InitSystemRequest Request, Action<Common.API.RemoteProtocolService.InitSystemResponse> InitSystemResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.InitSystemResponse>(() =>
            {
                if (InitSystemResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var initSystemResponse = e as Common.API.RemoteProtocolService.InitSystemResponse;
                        InitSystemResponse(initSystemResponse);
                    };
                }
                return _InitSystemSession.HandleRequest(Request);
            });
        }
        public Task<Common.API.RemoteProtocolService.InitSystemResponse> Format(Common.API.RemoteProtocolService.InitSystemRequest Request, Action<Common.API.RemoteProtocolService.InitSystemResponse> InitSystemResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.InitSystemResponse>(() =>
            {
                if (InitSystemResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var initSystemResponse = e as Common.API.RemoteProtocolService.InitSystemResponse;
                        InitSystemResponse(initSystemResponse);
                    };
                }
                return _InitSystemSession.HandleRequest(Request);
            });
        }
        public Task<Common.API.RemoteProtocolService.InitSystemResponse> PrintType(Common.API.RemoteProtocolService.InitSystemRequest Request, Action<Common.API.RemoteProtocolService.InitSystemResponse> InitSystemResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.InitSystemResponse>(() =>
            {
                if (InitSystemResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var initSystemResponse = e as Common.API.RemoteProtocolService.InitSystemResponse;
                        InitSystemResponse(initSystemResponse);
                    };
                }
                return _InitSystemSession.HandleRequest(Request);
            });
        }
        public Task<Common.API.RemoteProtocolService.InitSystemResponse> Print(Common.API.RemoteProtocolService.InitSystemRequest Request, Action<Common.API.RemoteProtocolService.InitSystemResponse> InitSystemResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.InitSystemResponse>(() =>
            {
                if (InitSystemResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var initSystemResponse = e as Common.API.RemoteProtocolService.InitSystemResponse;
                        InitSystemResponse(initSystemResponse);
                    };
                }
                return _InitSystemSession.HandleRequest(Request);
            });
        }
        #endregion

        #region Set Date
        public Task<Common.API.RemoteProtocolService.GetSetDateResponse> SetTime(Common.API.RemoteProtocolService.GetSetDateRequest Request, Action<Common.API.RemoteProtocolService.GetSetDateResponse> SetTimeResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.GetSetDateResponse>(() =>
            {
                if (SetTimeResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var setTimeResponse = e as Common.API.RemoteProtocolService.GetSetDateResponse;
                        SetTimeResponse(setTimeResponse);
                    };
                }

                return _SetGetTimeSession.HandleRequest(Request);
            });
        }
        public Task<Common.API.RemoteProtocolService.GetSetDateResponse> SetDate(Common.API.RemoteProtocolService.GetSetDateRequest Request, Action<Common.API.RemoteProtocolService.GetSetDateResponse> SetDateResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.GetSetDateResponse>(() =>
            {
                if (SetDateResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var setDateResponse = e as Common.API.RemoteProtocolService.GetSetDateResponse;
                        SetDateResponse(setDateResponse);
                    };
                }

                return _SetGetTimeSession.HandleRequest(Request);
            });
        }
        public Task<Common.API.RemoteProtocolService.GetSetDateResponse> GetFullDate(GetSetDateRequest Request, Action<Common.API.RemoteProtocolService.GetSetDateResponse> GetFullDateResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.GetSetDateResponse>(() =>
            {
                if (GetFullDateResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var getFullDateResponse = e as Common.API.RemoteProtocolService.GetSetDateResponse;
                        GetFullDateResponse(getFullDateResponse);
                    };
                }

                return _SetGetTimeSession.HandleRequest(Request);
            });
        }

        #endregion

        #region Rate

        public Task<Common.API.RemoteProtocolService.RateResponse> Rate(Common.API.RemoteProtocolService.RateRequest Request, Action<Common.API.RemoteProtocolService.RateResponse> RateResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.RateResponse>(() =>
            {
                if (RateResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var rateResponse = e as Common.API.RemoteProtocolService.RateResponse;
                        RateResponse(rateResponse);
                    };
                }
                return _RateSession.HandleRequest(Request);
            });
        }
        public Task<Common.API.RemoteProtocolService.RateResponse> SetInterval(Common.API.RemoteProtocolService.RateRequest Request, Action<Common.API.RemoteProtocolService.RateResponse> RateResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.RateResponse>(() =>
            {
                if (RateResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var rateResponse = e as Common.API.RemoteProtocolService.RateResponse;
                        RateResponse(rateResponse);
                    };
                }
                return _RateSession.HandleRequest(Request);
            });
        }

        #endregion

        #region Init Channels

        public Task<Common.API.RemoteProtocolService.InitChannelsResponse> InitChannels(Common.API.RemoteProtocolService.InitChannelsRequest Request, Action<Common.API.RemoteProtocolService.InitChannelsResponse> InitChannelsResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.InitChannelsResponse>(() =>
            {
                if (InitChannelsResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var initChannelsResponse = e as Common.API.RemoteProtocolService.InitChannelsResponse;
                        InitChannelsResponse(initChannelsResponse);
                    };
                }
                return _InitChannelsSession.HandleRequest(Request);
            });
        }

        #endregion

        #region Logs

        public Task<LogsResponse> GetLogs(LogsRequest Request, Action<LogsResponse> LogsResponse = null)
        {
            return Task.Factory.StartNew<LogsResponse>(() =>
            {
                if (LogsResponse != null)
                {
                    Request.CallBackResponse = (o, e) =>
                    {
                        var logsResponse = (LogsResponse)e;
                        LogsResponse(logsResponse);
                    };
                }

                return _LogsSession.HandleRequest(Request);
            });
        }

        #endregion

        #endregion

        #region Fire Events

        /// <summary>UTC of the last measurement this device broadcast; null until scanning produces data.
        /// Drives the ServerCore data-timeout watchdog (MBA-485 AC5/AC6 — comm-loss / DataTimeout / DataRestored).</summary>
        public DateTime? LastMeasurementUtc { get; private set; }

        /// <summary>Edge-detection flag for the data-timeout watchdog so DataTimeout/DataRestored alerts fire once per transition.</summary>
        public bool DataTimedOut { get; set; }

        /// <summary>Guards against a double disconnect alert when both the self-disconnect and comm-loss paths fire (MBA-485 AC5).</summary>
        public bool DisconnectAlerted { get; set; }

        /// <summary>
        /// MBA-967 (review of #30): the logger's MABA id (21-337) as the last client that named it
        /// unambiguously did (<see cref="ServerCore.ResolveAndRememberLoggerId"/>). Alerts to a client
        /// that has named no logger - a browser that just reconnected - use it rather than the serial,
        /// so a drop announced as 21-337 is not followed by a return announced as FLUKE,2625A. Kept on
        /// the host because the host outlives its links: ServerCore reuses it when a known serial is
        /// found again on a new one. Null until some client names it.
        /// </summary>
        public string LastKnownLoggerId
        {
            get { return System.Threading.Volatile.Read(ref _lastKnownLoggerId); }
            internal set { System.Threading.Volatile.Write(ref _lastKnownLoggerId, value); }
        }
        private string _lastKnownLoggerId;

        /// <summary>
        /// MBA-962: UTC of the last measurement whose values actually <em>differed</em> from the one
        /// before it. Null until the device has produced two distinct readings.
        /// <para>
        /// This exists because of what a station log showed during a communication interruption. The
        /// link never dropped - the serial port stayed open - and the server went on reading the
        /// instrument's log buffer and broadcasting the same entries over and over:
        /// <c>1,20.9917353964817</c> identical to thirteen decimal places, every 34 seconds, for
        /// minutes. To the operator the readings had stopped; to the watchdog, which only asked
        /// whether a broadcast had happened, the device looked perfectly healthy, so DataTimeout
        /// never fired and the recovery that would have fixed it never ran.
        /// </para>
        /// <para>
        /// MBA-967: values alone cannot tell those two apart from a stable bath. A Hydra reads to
        /// 0.1 °C, so a settled bath gives identical scans; on 2026-09-29 this fired three times in
        /// one night while the logger's own scan time moved on by 30 s on every read, and each time
        /// the recovery reset the logger and cost a 48 s gap in the data. Where the instrument
        /// reports when it scanned, that time is part of the comparison: a new scan time is a new
        /// measurement whatever its values, and a re-read log entry carries its old time.
        /// </para>
        /// </summary>
        public DateTime? LastDistinctMeasurementUtc { get; private set; }

        /// <summary>
        /// Whether repeated identical readings should count as a fault on this device. Off by
        /// default and switched on by the BL, because it is only true for an instrument that
        /// measures: a source reports the setpoint it was told to produce, and that value is
        /// supposed to stay exactly the same for as long as the operator leaves it alone.
        /// </summary>
        public bool StaleDataDetectionEnabled { get; set; }

        /// <summary>The values behind the previous broadcast, for comparison. Not a hash: the packet
        /// is short, and a collision here would hide the very fault this is looking for.</summary>
        private string _lastMeasurementSignature;

        /// <summary>
        /// What the watchdog should judge this device by. A device that repeats itself is only a
        /// fault where <see cref="StaleDataDetectionEnabled"/> says so; everywhere else this is the
        /// plain "did anything arrive" timestamp it has always been.
        /// </summary>
        public DateTime? WatchdogMeasurementUtc
        {
            get { return StaleDataDetectionEnabled ? LastDistinctMeasurementUtc : LastMeasurementUtc; }
        }

        /// <summary>MBA-962: UTC of the last power-cycle recovery attempt; null while the device is producing data.</summary>
        public DateTime? LastRecoveryAttemptUtc { get; set; }

        /// <summary>MBA-962: recovery attempts made since this device last produced data, so the retry is bounded.</summary>
        public int RecoveryAttempts { get; set; }

        /// <summary>
        /// MBA-974: set when a live WS config change wants this device's BL re-initialized. Must not
        /// be acted on inline on the WebSocket receive thread - that would race BL.OnTimer on the
        /// device tick thread (OnConnection(true) resets the state machine's step/index while a tick
        /// may be mid-DoWork) and, since OnCreateStates does a blocking SQL read, would also block the
        /// receive loop and stall anything waiting on DeviceHost_Slim's write lock. Mark here; the tick
        /// thread (ServerCore.CheckDataTimeouts) takes and acts on it between ticks instead, the same
        /// way MBA-962's power-cycle recovery already does. Interlocked so a mark from the WS thread
        /// and a take from the tick thread never race, and two marks before the next tick coalesce
        /// into a single re-init instead of one racing the other mid-sequence.
        /// </summary>
        private string _pendingReconfigureReason;

        /// <summary>Records that this device's BL should be re-initialized on the next tick.</summary>
        public void MarkPendingReconfigure(string reason)
        {
            System.Threading.Interlocked.Exchange(ref _pendingReconfigureReason, reason ?? "live reconfiguration from web app");
        }

        /// <summary>Atomically reads and clears the pending reconfigure reason, or null when none is set.</summary>
        public string TakePendingReconfigureReason()
        {
            return System.Threading.Interlocked.Exchange(ref _pendingReconfigureReason, null);
        }

        /*  MBA-967: "stop scan" from the logger window. A stopped logger is silent on purpose, and three
            things would otherwise start it again within about a minute: the data watchdog's power-cycle
            recovery (it reads the silence as a power cut), a live reconfiguration (the calibration graph
            re-sends the saved setup on mount and on every reconnect), and a reconnect of the link. So
            the host remembers the stop until the operator's next Confirm, whose Status:Start resumes it.
            Set on the WebSocket thread; the stop itself runs on the device tick thread
            (ServerCore.CheckDataTimeouts), for the same reason ReinitializeBL does - see
            MarkPendingReconfigure. */
        private volatile bool _scanStopped;
        private string _pendingStopReason;

        /// <summary>MBA-967: the operator stopped this device's scan and has not confirmed a new one since.</summary>
        public bool ScanStopped => _scanStopped;

        /// <summary>
        /// MBA-967: records the operator's stop; the next tick carries it out (<see cref="StopScanning"/>).
        /// From here on the watchdog, a live reconfiguration and a reconnect leave the device alone.
        /// </summary>
        public void RequestStopScanning(string reason)
        {
            _scanStopped = true;
            System.Threading.Interlocked.Exchange(ref _pendingStopReason, reason ?? "stop scan from web app");
        }

        /// <summary>Atomically reads and clears the pending stop, or null when none is set.</summary>
        public string TakePendingStopReason()
        {
            return System.Threading.Interlocked.Exchange(ref _pendingStopReason, null);
        }

        /// <summary>
        /// MBA-967: the operator confirmed a scan again (Status:Start). Clears the stop and asks for a
        /// re-init - needed even when the configuration is unchanged, because an unchanged
        /// LoggerConfiguration triggers none, and the stop reset the logger. A stop not yet carried out
        /// is simply dropped. False, and nothing marked, when the device was not stopped.
        /// </summary>
        public bool RequestResumeScanning(string reason)
        {
            if (!_scanStopped) return false;

            System.Threading.Interlocked.Exchange(ref _pendingStopReason, null);
            _scanStopped = false;
            MarkPendingReconfigure(reason ?? "scan resumed from web app");
            return true;
        }

        /// <summary>
        /// MBA-967: carries out a stop. Tick thread only (ServerCore.CheckDataTimeouts). Drops the
        /// requests queued and in flight - a poll's LOG_COUNT? or LOGGED? must not follow the stop - puts
        /// the watchdog back to idle, as for a device that has not been asked to scan, and has the BL
        /// stop and reset the instrument. Readings already broadcast are untouched.
        /// </summary>
        /// <returns>False when the BL has nothing to stop; the device is then not left marked stopped.</returns>
        public bool StopScanning(string reason)
        {
            var bl = this.BL;
            if (bl == null)
            {
                Libs.Trace.Tracer.Info("[STOP] SN={0} has no BL; nothing to stop ({1})", SN, reason);
                _scanStopped = false;
                return false;
            }

            // Asked before anything is cleared (review of #28): a BL that cannot stop keeps its queued
            // requests and its watchdog clock, so "left as it was" is literally true and its watchdog
            // goes on judging it from its last reading.
            if (!bl.CanStopScanning)
            {
                Libs.Trace.Tracer.Info("[STOP] SN={0}: its BL does not scan; left as it was ({1})", SN, reason);
                _scanStopped = false;
                return false;
            }

            Libs.Trace.Tracer.Info("[STOP] SN={0} stopping the scan: {1}", SN, reason);

            if (Sessions != null)
            {
                for (int i = 0; i < Sessions.Length; i++)
                {
                    Sessions[i].OnDisconnect();
                }
            }

            LastMeasurementUtc = null;
            LastDistinctMeasurementUtc = null;
            _lastMeasurementSignature = null;
            DataTimedOut = false;
            LastRecoveryAttemptUtc = null;
            RecoveryAttempts = 0;

            if (!bl.StopScanning(reason))
            {
                // Said it could stop, then did not. The requests and the watchdog are already reset,
                // so the line does not claim the device was left as it was.
                Libs.Trace.Tracer.Info("[STOP] SN={0}: its BL did not stop the scan; requests dropped and watchdog reset, but the device is not held stopped", SN);
                _scanStopped = false;
                return false;
            }
            return true;
        }

        /// <summary>
        /// MBA-967: the operator's reconfiguration restarts the scan, so the watchdog's 60 s start again
        /// from here instead of from the last reading before it. On the bench a Confirm at 14:50:27,
        /// 23 s after a reading, put the first new reading at 14:51:07; the watchdog, still counting from
        /// 14:50:04, fired "No data received for 60 seconds" at 14:51:04, and its power-cycle recovery
        /// reset a healthy logger a second time - 100 s without data instead of about 40.
        /// <para>
        /// Called twice per reconfiguration: by <c>ServerCore.CheckDataTimeouts</c> when it takes the
        /// re-init, and by the Hydra2 BL when its new polling loop starts, after the channel setup. The
        /// setup takes about 2 s per channel and the first reading then waits up to ~28 s more, so with
        /// 16-20 channels it lands 65-75 s after the first restart - past the 60 s on its own.
        /// </para>
        /// <para>
        /// Only for a device that is currently fine. One already declared silent keeps its clock, so a
        /// reconfiguration can neither hide a real fault nor announce a recovery that has not happened
        /// (the watchdog would read a fresh timestamp as "data resumed"). "Never measured" stays null,
        /// which the watchdog reads as idle, not silent. Power-cycle recovery does not come through here -
        /// see <c>RecoveryDoesNotClearTheStallTimestamp</c>.
        /// </para>
        /// </summary>
        /// <returns>True when the clock was restarted.</returns>
        public bool RestartWatchdogClockForReconfiguration(DateTime nowUtc)
        {
            if (DataTimedOut || !LastMeasurementUtc.HasValue) return false;

            LastMeasurementUtc = nowUtc;
            if (LastDistinctMeasurementUtc.HasValue) LastDistinctMeasurementUtc = nowUtc;
            return true;
        }

        /// <summary>
        /// MBA-962: the BL's way to report a fault it alone can see, as a WS alert about this device.
        /// <paramref name="channel"/> is the channel number as text, or "ALL" for a device-wide alert.
        /// </summary>
        public void RaiseAlert(string alertType, string message, string channel)
        {
            Libs.Trace.Tracer.Info("[ALERT] SN={0} Channel={1} {2}: {3}", SN, channel, alertType, message);
            MainEventsBus?.Fire_DeviceAlert(this, new Events.DeviceAlertEventArgs(this, alertType, message, channel));
        }

        /// <summary>
        /// MBA-962 (power-cycle recovery): re-run the BL's init sequence on a device that is still
        /// connected but has stopped producing data.
        ///
        /// A logger that loses power and comes back has forgotten its scan configuration, while the
        /// serial port stayed open the whole time — so nothing looks disconnected, no discovery pass
        /// will find it (the port is held), and the session that was polling for logs waits for a
        /// device that will never answer on its own. Only re-sending the setup sequence starts it
        /// scanning again.
        ///
        /// The sessions are reset first: OnDisconnect clears the in-flight request and drains the
        /// queue, so the restart does not begin behind a pile of requests aimed at the device's
        /// pre-power-cut state.
        /// </summary>
        /// <returns>false when there is no BL to restart, so the caller can log the difference
        /// between "recovery attempted" and "nothing to recover".</returns>
        public bool ReinitializeBL(string reason)
        {
            var bl = this.BL;
            if (bl == null)
            {
                Libs.Trace.Tracer.Info("[RECOVERY] SN={0} has no BL to re-initialize ({1})", SN, reason);
                return false;
            }

            Libs.Trace.Tracer.Info("[RECOVERY] SN={0} re-initializing the device BL: {1}", SN, reason);

            if (Sessions != null)
            {
                for (int i = 0; i < Sessions.Length; i++)
                {
                    Sessions[i].OnDisconnect();
                }
            }

            // OnConnection(true) is the BL's own restart: it rebuilds the state array, resets every
            // state and puts the machine back at the first step (*IDN?/*RST onward).
            bl.OnConnection(true);
            return true;
        }

        public void BroadcastMeasurement(int channel, double value)
        {
            LastMeasurementUtc = DateTime.UtcNow;
            var packet = new HardwarePacket(string.Format(System.Globalization.CultureInfo.InvariantCulture, "E,{0},{1},{2}", SN, channel, value), false);
            IncomingEvents(packet);
        }

        /// <param name="instrumentScanTime">The scan time as the instrument's own clock recorded it,
        /// when it records one. Only compared, never shown: it tells a new scan from a re-read one
        /// (see <see cref="LastDistinctMeasurementUtc"/>).</param>
        /// <param name="measuredAt">When the reading was taken, in the PC's local time, for the
        /// clients. Null sends the time of the broadcast, as before.</param>
        public void BroadcastAllMeasurements(System.Collections.Generic.List<int> channels, System.Collections.Generic.List<double> values,
                                             DateTime? instrumentScanTime = null, DateTime? measuredAt = null)
        {
            LastMeasurementUtc = DateTime.UtcNow;
            // Build multi-channel packet: E,SN,ch1,val1,ch2,val2,...
            var sb = new System.Text.StringBuilder();
            sb.Append("E,");
            sb.Append(SN);
            for (int i = 0; i < channels.Count && i < values.Count; i++)
            {
                sb.AppendFormat(System.Globalization.CultureInfo.InvariantCulture, ",{0},{1}", channels[i], values[i]);
            }
            var rawPacket = sb.ToString();

            // The packet already is the reading, channel by channel, so it is the signature. Compared
            // before the broadcast, and the broadcast still happens either way: a repeated value is a
            // fault to be reported, not a reason to starve the screen of the last thing we know.
            // The scan time joins the signature only when the instrument supplies one, so every other
            // instrument is judged exactly as before.
            var signature = instrumentScanTime.HasValue
                ? rawPacket + "@" + instrumentScanTime.Value.Ticks.ToString(System.Globalization.CultureInfo.InvariantCulture)
                : rawPacket;
            if (!string.Equals(signature, _lastMeasurementSignature, StringComparison.Ordinal))
            {
                _lastMeasurementSignature = signature;
                LastDistinctMeasurementUtc = DateTime.UtcNow;
            }

            Libs.Trace.Tracer.Info("[BroadcastAllMeasurements] SN={0}, {1} channels, raw packet: {2}", SN, channels.Count, rawPacket);
            var packet = new HardwarePacket(rawPacket, false) { MeasuredAt = measuredAt };
            IncomingEvents(packet);
        }

        internal void IncomingEvents(IPacket p)
        {
            var e = new Events.DeviceEventArgs(this, p);

            if (BL != null)
            {
                BL.OnEvent(e);
            }

            MainEventsBus.Fire_OnIncomingEvent(this, e);
        }

        #endregion

        #region private methods

        private void OnDisconnection()
        {
            Libs.Trace.Tracer.Info(true, $"#{SN} Disconnected");

            if (Sessions != null)
            {
                for (int i = 0; i < Sessions.Length; i++)
                {
                    Sessions[i].OnDisconnect();
                }
            }

            var bl = this.BL;
            if (bl != null)
            {
                bl.OnConnection(false);
            }

            // Comm-loss path: surface the disconnect so ServerCore can notify WS clients (MBA-485 AC5).
            // (The self-disconnect path in Disconnect() already fires this.)
            MainEventsBus?.Fire_DeviceConnection(this, new Events.DeviceConnectionEventArgs(this));
        }

        private void OnConnection()
        {
            Libs.Trace.Tracer.Info(true, $"#{SN} Connected");

            // MBA-485 AC5: arm the disconnect alert again. ServerCore reuses this instance when a
            // known SN reconnects (see AddPendingDevices - it calls InitSessions on the existing
            // host rather than creating one), so without this reset the flag stays true for the
            // life of the process and only the FIRST disconnect of a device is ever reported.
            var dropWasAlerted = DisconnectAlerted;
            DisconnectAlerted = false;

            // MBA-967: the app was told the logger dropped (ChannelDisconnected, Channel ALL), so it
            // has to be told it is back - on the bench the adapter was plugged in again, polling
            // restarted, and the app kept showing the logger as disconnected. DataRestored on ALL is
            // the pair the app closes that range with (deviceId:ALL). Only after a drop alert: the
            // first identification has nothing to restore, and a re-init (ReinitializeBL) never
            // comes through here.
            if (dropWasAlerted)
            {
                RaiseAlert("DataRestored",
                    string.Format("Logger {0} reconnected", Events.DeviceAlertEventArgs.LoggerNameToken),
                    "ALL");
            }

            // A device that reconnects has not produced data yet. Clearing this stops the watchdog
            // from firing DataTimeout off a stale pre-disconnect timestamp the moment it comes back.
            LastMeasurementUtc = null;
            DataTimedOut = false;

            // The same reasoning for the repeated-reading check, plus one of its own: the first
            // reading after a reconnect will often equal the last one before it, and that is a
            // stable temperature, not a stuck buffer.
            LastDistinctMeasurementUtc = null;
            _lastMeasurementSignature = null;

            // MBA-962: a device that has just reconnected gets its full recovery budget back. Without
            // this a device that used up its five attempts before being unplugged would come back
            // with none left, and the next power cycle would go unrecovered.
            LastRecoveryAttemptUtc = null;
            RecoveryAttempts = 0;

            var bl = this.BL;
            if (bl != null)
            {
                // MBA-967: a stopped logger stays stopped when its link comes back; only the next
                // Confirm (Status:Start -> RequestResumeScanning) sets it up and starts it again.
                // Not setting it up is not enough, though (review of #28): a stop carried out while the
                // link was down never reached the logger, and one cut off by the drop may have stopped
                // half way, so the logger can still be scanning into its own memory. The stop sequence
                // goes out again on every reconnect - SCAN 0 / LOG_CLR / *RST are harmless to a logger
                // already stopped. Still no init and no polling loop. This runs on the device tick
                // thread (DeviceTick -> InitSessions), like the stop itself; a Confirm arriving while
                // it runs re-inits, and the re-init's generation bump cuts the rest of it off.
                if (_scanStopped && bl.CanStopScanning)
                {
                    Libs.Trace.Tracer.Info("[STOP] SN={0} reconnected while its scan is stopped; sending the stop again, not setting it up until the next Confirm", SN);
                    try
                    {
                        bl.StopScanning("reconnected while its scan is stopped");
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info("[STOP] SN={0} sending the stop again after a reconnect threw: {1}", SN, ex.Message);
                    }
                    return;
                }
                bl.OnConnection(true);
            }
        }

        private void _executer_Destroy(ComLayer.IComLayer comLayer = null)
        {
            if (comLayer != null)
            {
                comLayer.LayerClosed -= _executer_Destroy;
                comLayer.DataReceived -= _executer_DataReceived;
            }

            if (InternalComLayer != null)
            {
                InternalComLayer.LayerClosed -= _executer_Destroy;
                InternalComLayer.DataReceived -= _executer_DataReceived;
                InternalComLayer = null;
            }
        }

        private void _executer_Destroy(object sender, ComLayer.DestroyedEventArgs e)
        {
            var _com = (ComLayer.IComLayer)sender;
            if (_com != null)
            {
                OnDisconnection();
                _executer_Destroy(_com);
            }
        }

        private void _executer_DataReceived(object sender, ComLayer.DataReceivedEventArgs e)
        {
            if (DeviceSettings.IdentificationType == DeviceSettings.IdentificationTypes.Modbus)
            {
                ProtocolParser.OnData(e.FloatData);

            }
            else
            {
                ProtocolParser.OnData(e.Data, e.Offset, e.Count);
            }
        }

        /// <summary>
        /// True when an identification reply names a Keysight 1000 X-Series scope. The model token is
        /// matched with spaces and hyphens stripped, because the instrument reports "EDU-X 1002A"
        /// while the datasheet, the settings and our own SN use "EDUX1002A".
        /// </summary>
        internal static bool IsKeysight1000XSeries(string identificationReply)
        {
            if (string.IsNullOrEmpty(identificationReply))
                return false;

            var normalized = identificationReply.Replace(" ", "").Replace("-", "").Replace("_", "");
            return normalized.IndexOf("EDUX1002", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        /// <summary>
        /// True when an identification reply names a Fluke 5322A electrical tester calibrator.
        /// <para>
        /// ⚠️ The model this instrument reports is a MENU SETTING, not a fixed fact. With 5320A
        /// emulation off it answers "FLUKE,5322A,&lt;serial&gt;,&lt;firmware&gt;"; with emulation on
        /// the SAME unit answers "FLUKE,5320A,...". Both spellings are matched here and normalised to
        /// one SN, because otherwise an operator flipping that menu on the front panel takes the
        /// instrument out of the server with no error anywhere.
        /// </para>
        /// </summary>
        internal static bool IsFluke5322a(string identificationReply)
        {
            if (string.IsNullOrEmpty(identificationReply))
                return false;

            if (identificationReply.IndexOf("FLUKE", StringComparison.OrdinalIgnoreCase) < 0)
                return false;

            return identificationReply.IndexOf("5322A", StringComparison.OrdinalIgnoreCase) >= 0
                || identificationReply.IndexOf("5320A", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        /// <summary>
        /// True when an identification reply names a Meatest M-142 calibrator, whose <c>*IDN?</c>
        /// answers "MEATEST,M-142,&lt;serial&gt;,&lt;firmware&gt;".
        /// <para>
        /// Both halves are required. The model number alone is matched with spaces and hyphens
        /// stripped (the instrument writes "M-142", the settings and our SN use the same spelling but
        /// a reply could reasonably print "M 142"), and the vendor name keeps that loose model match
        /// from claiming an unrelated instrument whose reply happens to contain those digits.
        /// </para>
        /// </summary>
        internal static bool IsMeatestM142(string identificationReply)
        {
            if (string.IsNullOrEmpty(identificationReply))
                return false;

            if (identificationReply.IndexOf("MEATEST", StringComparison.OrdinalIgnoreCase) < 0)
                return false;

            var normalized = identificationReply.Replace(" ", "").Replace("-", "").Replace("_", "");
            return normalized.IndexOf("M142", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private void handlePacket(object o, Common.PacketEventArgs e)
        {

            Libs.Trace.Tracer.Info("PACKET <RX> " + e.P.ToString());
            var res = e.P.ToString();

            if (SN == null)
            {
                if (DeviceSettings.IdentificationType == DeviceSettings.IdentificationTypes.Modbus)
                {
                    SN = "Optidew";
                }
                else if (res.IndexOf("5522A", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    // Fluke 5522A calibrator. Verified live 2026-09-03: *IDN? answers
                    // "FLUKE,5522A,1972905,1.1+1.3+1.8".
                    // Placed before the vendor-level "FLUKE" branch below, which takes the first 11
                    // characters - that rule exists for the Hydra loggers ("FLUKE,2625A") and giving
                    // the calibrator its own model SN keeps the two families cleanly apart.
                    SN = "5522A";
                }
                else if (IsFluke5322a(res))
                {
                    // Fluke 5322A electrical tester calibrator. NOT yet verified live; per the
                    // Operators Manual *IDN? answers "FLUKE,5322A,<serial>,<firmware>", or
                    // "FLUKE,5320A,..." when 5320A emulation is switched on - both are normalised to
                    // this one SN so a front-panel menu cannot silently unclaim the instrument.
                    // Placed before the vendor-level "FLUKE" branch below for the same reason the
                    // 5522A branch is: that branch takes the first 11 characters, a rule that exists
                    // for the Hydra loggers ("FLUKE,2625A").
                    SN = "5322A";
                }
                else if (res.Contains("FLUKE"))
                {
                    SN = res.Substring(0, 11);
                }
                else if (res.IndexOf("53181A", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    // HP 53181A counter. Verified live 2026-09-02: *IDN? answers
                    // "HEWLETT-PACKARD,53181A,0,3703".
                    // ⚠️ This branch MUST come before the "HEWLETT" one below: that branch takes the
                    // first 15 characters, which is "HEWLETT-PACKARD" for this counter and for the
                    // 34401A multimeter alike. Sharing an SN would let Agilent34401aBLCore (token
                    // "HEWLETT") claim the counter and drive it with multimeter commands, and would
                    // collide in BaseBLCore's per-SN dictionary if both were on the bench.
                    SN = "53181A";
                }
                else if (res.Contains("HEWLETT"))
                {
                    SN = res.Substring(0, 15);
                }
                else if (res.Contains("TAU"))
                {
                    SN = res.Substring(0, 32);
                }
                else if (res.Contains("TTI"))
                {
                    SN = res.Substring(0, 6);
                }
                else if (res.Contains("Instek"))
                {
                    SN = "Instek";
                }
                else if (IsMeatestM142(res))
                {
                    // Meatest M-142 multifunction calibrator. NOT yet verified live; per the manual
                    // *IDN? answers "MEATEST,M-142,412341,4.6". Matched on vendor + model so a
                    // Meatest M-140 or M-143 on the same bus is not claimed by this BL.
                    SN = "M-142";
                }
                else if (res.IndexOf("PRODIGIT_3111", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    // PRODIGIT 3111 DC electronic load over RS-232. Verified live 2026-09-02: *IDN?
                    // answers the bare model token "PRODIGIT_3111" - no vendor, serial or firmware
                    // fields, unlike every other instrument here.
                    SN = "PRODIGIT_3111";
                }
                else if (res.IndexOf("CNT-90", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    // Pendulum CNT-90 counter. Verified live 2026-09-01: *IDN? answers
                    // "PENDULUM, CNT-90, 938636, V1.14 28 Jun 2006". Matched on the model, since the
                    // same vendor also ships the CNT-91 with a different BL.
                    SN = "CNT-90";
                }
                else if (res.IndexOf("SDG6052X", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    // Siglent SDG6052X generator. Verified live 2026-09-01: *IDN? answers
                    // "Siglent Technologies,SDG6052X,SDG6XEBD4R0879,6.01.01.35R5B1".
                    SN = "SDG6052X";
                }
                else if (IsKeysight1000XSeries(res))
                {
                    // Keysight InfiniiVision EDUX1002A oscilloscope. Verified live 2026-09-01: *IDN?
                    // answers "KEYSIGHT TECHNOLOGIES,EDU-X 1002A,CN59280205,01.10.2018012838" - the
                    // model is spelled "EDU-X 1002A", with a hyphen and a space, NOT "EDUX1002A" as the
                    // datasheet's model number suggests. Matched on the model rather than the vendor,
                    // which is shared with every other Keysight instrument, and normalised so both
                    // spellings identify the device. SN is the canonical form the BLCore matches.
                    SN = "EDUX1002A";
                }
                else if (res.IndexOf("DATRON", StringComparison.OrdinalIgnoreCase) >= 0
                      || res.IndexOf("WAVETEK", StringComparison.OrdinalIgnoreCase) >= 0
                      || res.Contains("9100"))
                {
                    // Datron/Wavetek 9100 calibrator (GPIB). Exact *IDN? text to be confirmed
                    // against the programming manual; matched on the model/vendor token for now.
                    SN = "Datron9100";
                }
                IdentificationDate = DateTime.Now;
            }

            // NOTE: Raw E, scan packets are NOT broadcast here to avoid duplicates.
            // The BL layer (Hydra2DeviceBL.HandleLogData) reads log entries and
            // calls BroadcastAllMeasurements() which is the single broadcast path.

            if (PacketReceived != null)
            {
                PacketReceived(this, e);
            }

            #region Sessions
            if (Sessions != null)
            {
                for (int i = 0; i < Sessions.Length; i++)
                {
                    try
                    {
                        Sessions[i].HandlePacket(e.P as HardwarePacket);
                    }
                    catch (Exception ex)
                    {
                        Libs.Trace.Tracer.Info("[Session] HandlePacket error in session {0}: {1}", i, ex.Message);
                    }
                }
            }
            #endregion
        }

        public void Dispose()
        {
            Disconnect();
        }

        #endregion
    }
}
