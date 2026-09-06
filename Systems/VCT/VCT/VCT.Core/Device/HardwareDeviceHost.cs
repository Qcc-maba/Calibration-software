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
            if (device != null)
            {
                ReplaceComLayer(device.InternalComLayer);
            }
            OnConnection();
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

        public void BroadcastMeasurement(int channel, double value)
        {
            LastMeasurementUtc = DateTime.UtcNow;
            var packet = new HardwarePacket(string.Format(System.Globalization.CultureInfo.InvariantCulture, "E,{0},{1},{2}", SN, channel, value), false);
            IncomingEvents(packet);
        }

        public void BroadcastAllMeasurements(System.Collections.Generic.List<int> channels, System.Collections.Generic.List<double> values)
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
            Libs.Trace.Tracer.Info("[BroadcastAllMeasurements] SN={0}, {1} channels, raw packet: {2}", SN, channels.Count, rawPacket);
            var packet = new HardwarePacket(rawPacket, false);
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
            DisconnectAlerted = false;

            // A device that reconnects has not produced data yet. Clearing this stops the watchdog
            // from firing DataTimeout off a stale pre-disconnect timestamp the moment it comes back.
            LastMeasurementUtc = null;
            DataTimedOut = false;

            var bl = this.BL;
            if (bl != null)
            {
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
