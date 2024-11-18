using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using System.Timers;

namespace Maba.VCT.Core
{
    public class ServerCore
    {
        #region members

        private Dictionary<string, VCTDeviceSettings> Dic_DeviceSettings = new Dictionary<string, VCTDeviceSettings>();

        #endregion

        #region properties

        public Settings.VCTSettings CurrentServerSettings { get; private set; }

        public Events.EventsBus7E MainEventsBus { get; private set; }

        #endregion

        #region Members

        private Timer TimerManager_DeviceHost = null;

        private Accessories.MyReaderWriterLockSlim<ConcurrentDictionary<string, Device.DeviceHost>> DeviceHost_Slim = new Accessories.MyReaderWriterLockSlim<ConcurrentDictionary<string, Device.DeviceHost>>(new ConcurrentDictionary<string, Device.DeviceHost>());
        private Accessories.MyReaderWriterLockSlim<List<Device.DeviceHostPending>> DeviceHost_Pending_Slim = new Accessories.MyReaderWriterLockSlim<List<Device.DeviceHostPending>>(new List<Device.DeviceHostPending>());

        private List<Socket> Device_MainSockets = null;

        #endregion

        #region ctor

        public ServerCore()
        {
            this.MainEventsBus = new Events.EventsBus7E();
            CurrentServerSettings = new Settings.VCTSettings();
        }

        #endregion

        #region public Methods

        public void Start()
        {
            Start(Settings.VCTSettings.Read());
        }

        public void Start(Settings.VCTSettings _Settings)
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
            TimerManager_DeviceHost.Elapsed += TimerManager_Hydra2_Elapsed;
            TimerManager_DeviceHost.AutoReset = false;
            TimerManager_DeviceHost.Start();

            #endregion
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

            TimerManager_DeviceHost.Elapsed -= TimerManager_Hydra2_Elapsed;
            TimerManager_DeviceHost.Stop();
            TimerManager_DeviceHost = null;

            #endregion
        }

        private VCTDeviceSettings Lookup4Settings(string name)
        {
            VCTDeviceSettings value = null;
            if (Dic_DeviceSettings.TryGetValue(name, out value))
            {
                if (value != null)
                {
                    return value;
                }
            }

            return new VCTDeviceSettings();
        }

        public void AddDevice_Pending_ComLayer(ComLayer.IComLayer layer)
        {

            var deviceSettings = Lookup4Settings(layer.ParentTunnel.Name);

            var g = new Device.DeviceHostPending()
            {
                D = new Device.DeviceHost(MainEventsBus, layer, deviceSettings.Clone())
            };

            DeviceHost_Pending_Slim.MyWriteLock(list =>
                    {
                        list.Add(g);
                    });

            MainEventsBus.Fire_UnIdentifiedConnection(this, new Events.DeviceConnectionEventArgs(g.D));
        }

        public Task<Device.DeviceHost> GetDeviceAsync(string sn)
        {
            return Task.Run<Device.DeviceHost>(() => GetDevice(sn));
        }

        public Device.DeviceHost GetDevice(string sn)
        {
            Device.DeviceHost dev = null;

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
                var _state = (Tuple<ComLayer.Tunnel, Socket>)ar.AsyncState;
                try
                {
                    var newSocket = _state.Item2.EndAccept(ar);
                    var s = new ComLayer.SocketCom(newSocket, _state.Item1);
                    this.AddDevice_Pending_ComLayer(s);
                    s.Open();
                }
                catch
                {
                }

                _state.Item2.BeginAccept(new AsyncCallback(DevicesSocket_Accpet_AsyncCallback), _state);
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


        void TimerManager_Hydra2_Elapsed(object sender, ElapsedEventArgs e)
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
                                    if (pendinHydra2lenceTime >= CurrentServerSettings.PendingDevice_FirstAwakePacket_TimeSpan
                                    && (!dev.LastAwakeConnectPacket.HasValue
                                    || NowTime - dev.LastAwakeConnectPacket.Value >= CurrentServerSettings.PendingDevice_AwakePacketInterval_TimeSpan)
                                    && (dev.TotalAwakeConnectPackets < CurrentServerSettings.PendingDevice_MaxAwakePacketTimes))
                                    {
                                        dev.LastAwakeConnectPacket = DateTime.UtcNow;
                                        dev.TotalAwakeConnectPackets++;
                                        var p = Common.HydraProtocolHelper.Build_ID_Packet();
                                        dev.D.SendPacket(p);
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
                Device.DeviceHost _DeviceHost = null;
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
                        _DeviceHost.InitSessions(newPending.D);
                        newPending.D.ReplaceComLayer(null);
                    }

                    else
                    {
                        _DeviceHost = newPending.D;
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
