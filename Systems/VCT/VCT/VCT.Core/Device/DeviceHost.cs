using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Core.Device.Sessions;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device
{
    public class DeviceHost
    {
        #region Members

        //private Events.EventsBus7E MainEventsBus = null;
        private Common.IProtocolParser ProtocolParser = null;

        #endregion

        #region Properties

        public IDeviceBL BL { get; set; }
        public DateTime? IdentificationDate { get; private set; }

        public VCTDeviceSettings DeviceSettings { get; internal set; }

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

        public DeviceHost(Events.EventsBus7E bus, ComLayer.IComLayer comLayer, VCTDeviceSettings deviceSettings)
        {
            this.DeviceSettings = deviceSettings;
            ReplaceComLayer(comLayer);

            Libs.Trace.Tracer.Info($"New Connection ({comLayer.Title})");

            ProtocolParser = new Common.Hydra2ProtocolParser()
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

        internal void InitSessions(DeviceHost device = null)
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

        internal void ReplaceComLayer(ComLayer.IComLayer comLayer)
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
        public bool SendPacket(Common.Packet p)
        {
            if (p == null)
            {
                return false;
            }


            var _com = InternalComLayer;

            if (IsConnected && _com != null)
            {
                //change TransactionId when it's out original Common.Packet

                Libs.Trace.Tracer.Info("PACKET <TX> " + p.ToString());

                //_com.SendBytes(p.ToBytes());
                _com.SendString(p.Command);
                if (PacketSent != null)
                {
                    PacketSent(this, new Common.PacketEventArgs(p));
                }

                return true;
            }

            return false;
        }

        public void Disconnect()
        {
            if (!IsConnected)
                return;

            Libs.Trace.Tracer.Info(true, $"#{SN} Self Disconnection");

            var com = this.InternalComLayer;
            com.Close();
            _executer_Destroy();
            //MainEventsBus.Fire_DeviceConnection(this, new Events.DeviceConnectionEventArgs(this));

            if (BL != null)
            {
                BL.OnConnection(false);
            }
            //TODO BL.Disconnect().
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
            }
            if (this.IsConnected)
            {
                var now = DateTime.UtcNow;
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

        public Task<Common.API.RemoteProtocolService.LogsResponse> GetLogs(Common.API.RemoteProtocolService.LogsRequest Request, Action<Common.API.RemoteProtocolService.LogsResponse> LogsResponse = null)
        {
            return Task.Factory.StartNew<Common.API.RemoteProtocolService.LogsResponse>(() =>
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
            ProtocolParser.OnData(e.Data, e.Offset, e.Count);
        }

        private void handlePacket(object o, Common.PacketEventArgs e)
        {
            Libs.Trace.Tracer.Info("PACKET <RX> " + e.P.ToString());
            var res = e.P.ToString();

            if (SN == null)
            {
                if (res.Contains("FLUKE"))
                {
                    SN = res.Substring(0, 11);
                }
            }

            if (PacketReceived != null)
            {
                PacketReceived(this, e);
            }

            #region Sessions

            if (Sessions != null)
            {
                for (int i = 0; i < Sessions.Length; i++)
                {
                    Sessions[i].HandlePacket(e.P);
                }
            }

            #endregion

        }



        #endregion
    }
}
