using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using System.Timers;

namespace Maba.VCT.DIGI.APIProtocol
{
    public class DigiGatewayCore
    {
        #region properties
        private Accessories.MyReaderWriterLockSlim<ConcurrentDictionary<string, APIProtocol>> APIProtocols_Slim = new Accessories.MyReaderWriterLockSlim<ConcurrentDictionary<string, APIProtocol>>(new ConcurrentDictionary<string, APIProtocol>());
        private List<Socket> API_MainSockets = null;
        private Timer TimerManager_DigiAPI = null;

        public Events.EventsBusDigi MainEventsBus { get; private set; }
        public Settings.DigiSettings CurrentServerSettings { get; private set; }

        #endregion

        #region ctor

        public DigiGatewayCore()
        {
            MainEventsBus = new Events.EventsBusDigi();
        }

        #endregion

        #region public API

        public void Start()
        {
            Start(Settings.DigiSettings.Read());
        }
        public void Start(Settings.DigiSettings DigiGatewaySettings)
        {
            CurrentServerSettings = Settings.DigiSettings.Read();

            API_MainSockets = new List<Socket>();

            foreach (var t in CurrentServerSettings.Tunnels)
            {
                foreach (var p in t.Ports)
                {
                    API_MainSockets.AddRange(StartSockets(p, t, APISocket_Accpet_AsyncCallback));
                }
            }

            #region API Timer init

            TimerManager_DigiAPI = new Timer();
            TimerManager_DigiAPI.Interval = 200;
            TimerManager_DigiAPI.Elapsed += TimerManager_DigiAPI_Elapsed;
            TimerManager_DigiAPI.AutoReset = false;
            TimerManager_DigiAPI.Start();

            #endregion
        }

        public void Stop()
        {
            CurrentServerSettings = null;
            if (API_MainSockets != null)
            {
                foreach (var item in API_MainSockets)
                {
                    item.Close();
                }
                API_MainSockets = null;
            }

            TimerManager_DigiAPI.Stop();
            TimerManager_DigiAPI.Elapsed -= TimerManager_DigiAPI_Elapsed;
            APIProtocols_Slim.MyWriteLock(list =>
            {
                Parallel.ForEach(list, dev =>
                {
                    try
                    {
                        dev.Value.Close();
                    }
                    catch (Exception)
                    {
                    }
                });
                list.Clear();
            });

            TimerManager_DigiAPI = null;
        }

        #endregion

        #region Private Method

        private Socket[] StartSockets(int port, ComLayer.Tunnel tunnel, AsyncCallback acceptCallback)
        {

            var sockets = new List<Socket>();
            try
            {
                var ip = String.IsNullOrEmpty(tunnel.Address) ? IPAddress.Any : Dns.GetHostEntry(tunnel.Address).AddressList.Where(a => a.AddressFamily == AddressFamily.InterNetwork).FirstOrDefault();
                var ep = new IPEndPoint(ip, port);
                var s = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
                s.Bind(ep);
                s.Listen(300);
                s.BeginAccept(new AsyncCallback(acceptCallback), new Tuple<Socket, ComLayer.Tunnel>(s, tunnel));
                sockets.Add(s);
            }
            catch (Exception)
            {
            }
            return sockets.ToArray();
        }

        private void APISocket_Accpet_AsyncCallback(IAsyncResult ar)
        {
            try
            {
                var data = (Tuple<Socket, ComLayer.Tunnel>)ar.AsyncState;

                try
                {
                    var IncomingSocket = data.Item1.EndAccept(ar);
                    var s = new ComLayer.SocketCom(IncomingSocket, data.Item2);
                    this.AddAPIComLayer(s);
                    s.Open();
                }
                catch { }

                data.Item1.BeginAccept(new AsyncCallback(APISocket_Accpet_AsyncCallback), data);
            }
            catch (Exception)
            {
            }
        }


        public void AddAPIComLayer(ComLayer.IComLayer c)
        {
            var a = new APIProtocol(c);
            MainEventsBus.Fire_NewGateWay_Event(this, new Events.NewGateWayConnectionEventArgs(a));

            int ApiProtocolsCount = 0;

            APIProtocols_Slim.MyWriteLock(list =>
            {
                list.TryAdd(a.InternalComLayer.Title, a);
                ApiProtocolsCount = list.Count;
            });
        }

        #endregion

        #region Timer 

        void TimerManager_DigiAPI_Elapsed(object sender, ElapsedEventArgs e)
        {
            if (TimerManager_DigiAPI == null)
                return;

            DateTime NowTime = DateTime.UtcNow;

            #region API Check (for closed, timeout etc..)

            try
            {
                int OriginalCount = 0;
                int ModifiedCount = 0;

                #region Check (Parallel)

                APIProtocols_Slim.MyReadLock(list =>
                {
                    ModifiedCount = OriginalCount = list.Count;

                    Parallel.ForEach(list, (api, state) =>
                    {
                        if (!api.Value.IsConnected)
                        {
                            api.Value.NewNodeNotification -= a_NewNodeNotification;
                            api.Value.Close();

                            System.Threading.Interlocked.Decrement(ref ModifiedCount);

                            //FireUpdateAPIConnection(new UpdateConnectionEventArgs<Digi.APIProtocol>(api.Value, false));
                        }
                    });
                });

                #endregion

                #region Remove closed (Parallel)

                if (ModifiedCount != OriginalCount)
                {
                    APIProtocol a = null;
                    APIProtocols_Slim.MyWriteLock(list =>
                    {
                        Parallel.ForEach(list, item =>
                        {
                            if (item.Value.IsClosed)
                            {
                                list.TryRemove(item.Key, out a);
                            }
                        });
                    });
                }

                #endregion
            }
            catch { }

            #endregion

            #region Timer (Parallel)

            try
            {
                APIProtocols_Slim.MyReadLock(list =>
                {
                    Parallel.ForEach(list, item =>
                    {
                        if (!item.Value.IsClosed)
                        {
                            item.Value.Timer();
                        }
                    });
                });
            }
            catch { }

            var t = TimerManager_DigiAPI;

            if (t != null)
            {
                t.Start();
            }

            #endregion
        }

        #endregion

        #region Event methods

        void a_NewNodeNotification(object sender, NewNodeNotificationEventArgs e)
        {
            // AddDevice_Pending_ComLayer(e.Node);
            MainEventsBus.Fire_New_Node_Connection(this, new Events.NewEndPointConnectionEventArgs(e.Node));
        }

        #endregion
    }
}
