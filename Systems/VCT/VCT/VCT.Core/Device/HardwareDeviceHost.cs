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

        public void BroadcastMeasurement(int channel, double value)
        {
            var packet = new HardwarePacket(string.Format(System.Globalization.CultureInfo.InvariantCulture, "E,{0},{1},{2}", SN, channel, value), false);
            IncomingEvents(packet);
        }

        public void BroadcastAllMeasurements(System.Collections.Generic.List<int> channels, System.Collections.Generic.List<double> values)
        {
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
        }

        private void OnConnection()
        {
            Libs.Trace.Tracer.Info(true, $"#{SN} Connected");

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
                else if (res.Contains("FLUKE"))
                {
                    SN = res.Substring(0, 11);
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
