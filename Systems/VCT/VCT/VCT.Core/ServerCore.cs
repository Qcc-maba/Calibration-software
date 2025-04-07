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
using System.Timers;
using System.Web;
using static System.Net.WebRequestMethods;

namespace Maba.VCT.Core
{
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
        string WebSocketAddress = "http://localhost:50001/";
        HttpListenerContext context;
        #endregion



        #region DB Members
        public MSSqlServer connector = null;
        #endregion

        #endregion

        #region ctor

        public ServerCore()
        {
            this.MainEventsBus = new Events.EventsBus();
            CurrentServerSettings = new Settings.VCTSettings();
        }

        #endregion

        #region public Methods

        public void Start()
        {
            Start(Settings.VCTSettings.Read());
        }

        public async void Start(Settings.VCTSettings _Settings)
        {
            CurrentServerSettings = _Settings;

            #region cache device settings

            Dic_DeviceSettings.Clear();
            foreach (var s in CurrentServerSettings.DeviceSettings)
            {
                Dic_DeviceSettings[s.SettingsName] = s;
            }

            #endregion

            //Device.OTA.OTAService.CurrentServerSettings = CurrentServerSettings;
            Device_MainSockets = new List<Socket>();
            foreach (var t in CurrentServerSettings.Tunnels)
            {
                Device_MainSockets.AddRange(StartSockets(t, DevicesSocket_Accpet_AsyncCallback));
            }

            #region Device Host Timer init

            TimerManager_DeviceHost = new Timer();
            TimerManager_DeviceHost.Interval = CurrentServerSettings.ServerTimerInterval;
            TimerManager_DeviceHost.Elapsed += TimerManager_Device_Elapsed;
            TimerManager_DeviceHost.AutoReset = true;
            TimerManager_DeviceHost.Start();

            #endregion

            #region WebSocket
            //WebSocketInit();
            #endregion

            #region DB connector
            connector = new MSSqlServer(CurrentServerSettings.GeneralDBName);
            await connector.OpenAsync();
            #endregion
        }

        private async void WebSocketInit()
        {
            try
            {

                _listener = new HttpListener();
                _listener.Prefixes.Add(WebSocketAddress);
                _listener.Start();
                context = await _listener.GetContextAsync();
                if (context != null && context.Request.IsWebSocketRequest)
                {

                    HttpListenerWebSocketContext webSocketContext = await context.AcceptWebSocketAsync(null);
                    WebSocket webSocket = webSocketContext.WebSocket;
                    WebSocketCom wsc = new WebSocketCom(webSocket);
                    WebSocketDeviceHost wsdh = new WebSocketDeviceHost(MainEventsBus, wsc, "Eliran");
                    WSDeviceHost_Slim.MyWriteLock(list =>
                    {
                        list.TryAdd("Eliran", wsdh);
                    });

                    MainEventsBus.Fire_WebSocketConnection(this, new Events.DeviceConnectionEventArgs(wsdh));


                    Console.WriteLine("Client connected!");

                }

            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info(ex.Message);
            }
        }

        public void Stop()
        {
            CurrentServerSettings = null;

            foreach (var item in Device_MainSockets)
            {
                item.Close();
            }

            Device_MainSockets = null;

            #region Device_Pending

            DeviceHost_Pending_Slim.MyWriteLock(list =>
        {
            Parallel.ForEach(list, dev =>
            {
                try
                {
                    dev.D.Disconnect();
                }
                catch (Exception)
                {
                }
            });
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

            TimerManager_DeviceHost.Elapsed -= TimerManager_Device_Elapsed;
            TimerManager_DeviceHost.Stop();
            TimerManager_DeviceHost = null;

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
                                pendinHydra2lenceTime = NowTime - dev.D.InternalComLayer.CreationTime;

                                if (pendinHydra2lenceTime > CurrentServerSettings.PendingDevice_MaximumSilence_TimeSpan)
                                {
                                    dev.D.Disconnect();
                                    dev.Remove = true;
                                }
                                else
                                {
                                    dev.D.SendPacket(CurrentServerSettings.DeviceSettings.FirstOrDefault().IdentificationPacket);
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
            catch
            {
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
