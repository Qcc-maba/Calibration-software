using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.Core
{
    public class MultiBLCommServer
    {
        #region members

        private CommonBL.IBLCore[] _BlCores = null;

        #endregion

        #region properties

        public Settings.ComServerSettings CurrentSettings { get; set; }
        //public DIGI.APIProtocol.Settings.DigiSettings Settings4DigiServer { get; set; }
        public VCT.Core.Settings.VCTSettings Settings4VCTServer { get; set; }
        //public DIGI.APIProtocol.DigiGatewayCore DigiGatewayCore { get; private set; }
        public VCT.Core.ServerCore VCTServer { get; private set; }

        #endregion

        #region Events 

        public delegate void New7EDeviceConnectedDelegate(object o, VCT.Core.Events.DeviceConnectionEventArgs e);
        public event New7EDeviceConnectedDelegate NewDeviceConnected;

        //public delegate void NewDigiGatewayConnectedDelegate(object o, DIGI.APIProtocol.Events.NewGateWayConnectionEventArgs e);
        //public event NewDigiGatewayConnectedDelegate NewDigiGatewayConnected;

        #endregion

        #region public methods

        public void Start()
        {
            Console.ForegroundColor = ConsoleColor.Blue;
            VCT.Libs.Trace.Tracer.Info("CommServer - Starting....");
            Console.ForegroundColor = ConsoleColor.Gray;

            #region Digi

            ////this.Settings4DigiServer = DIGI.APIProtocol.Settings.DigiSettings.Read();

            //if (this.Settings4DigiServer != null)
            //{
            //    Console.ForegroundColor = ConsoleColor.Green;
            //    VCT.Libs.Trace.Tracer.Info("DIGI API Protocol Server");
            //    Console.ForegroundColor = ConsoleColor.Gray;

            //    if (this.Settings4DigiServer.Tunnels == null || this.Settings4DigiServer.Tunnels.Length == 0)
            //    {
            //        VCT.Libs.Trace.Tracer.Info("DIGI API Server Enabled without Tunnels.");
            //    }
            //    else
            //    {
            //        VCT.Libs.Trace.Tracer.Info("-- Starting DIGI API Server...");

            //        try
            //        {
            //            DigiGatewayCore = new DIGI.APIProtocol.DigiGatewayCore();
            //            DigiGatewayCore.MainEventsBus.GateWayConnnection += MainEventsBus_GateWayConnnection;
            //            DigiGatewayCore.MainEventsBus.NewNodeConnection += MainEventsBus_NewNodeConnection;
            //            DigiGatewayCore.Start(Settings4DigiServer);

            //            VCT.Libs.Trace.Tracer.Info("- Started!");

            //            for (int i = 0; i < this.Settings4DigiServer.Tunnels.Length; i++)
            //            {
            //                var t = this.Settings4DigiServer.Tunnels[i];
            //                VCT.Libs.Trace.Tracer.Info("-- ->DIGI Tunnel [{0}]", t.Name);
            //                VCT.Libs.Trace.Tracer.Info("-- ----Address : {0}", t.Address ?? "");
            //                VCT.Libs.Trace.Tracer.Info("-- ----Ports : {0}", String.Concat(t.Ports.Select(p => p.ToString() + ',')));
            //            }
            //        }
            //        catch (Exception e)
            //        {
            //            VCT.Libs.Trace.Tracer.Exception("Failed to run DIGI server", e);
            //        }
            //    }

            //    VCT.Libs.Trace.Tracer.Info();
            //}

            #endregion

            #region VCT

            this.Settings4VCTServer = VCT.Core.Settings.VCTSettings.Read();

            Console.ForegroundColor = ConsoleColor.Green;
            VCT.Libs.Trace.Tracer.Info("VCT Server Starting.");
            Console.ForegroundColor = ConsoleColor.Gray;

            if (this.Settings4VCTServer != null)
            {
                if (this.Settings4VCTServer.Tunnels == null || this.Settings4VCTServer.Tunnels.Length == 0)
                {
                    VCT.Libs.Trace.Tracer.Info("VCT Server Enabled without Tunnels.");
                }
                else
                {
                    VCT.Libs.Trace.Tracer.Info("-- Starting VCT Server...");

                    try
                    {
                        //VCT server
                        VCTServer = new VCT.Core.ServerCore();
                        VCTServer.MainEventsBus.DeviceOnIncomingEvent += VCT_MainEventsBus_DeviceOnIncomingEvent;
                        VCTServer.MainEventsBus.DeviceConnnection += VCT_MainEventsBus_DeviceConnnection;
                        VCTServer.MainEventsBus.AutoHandleNewDevices = true;
                        VCTServer.Start(Settings4VCTServer);

                        VCT.Libs.Trace.Tracer.Info("-- VCT Started!");

                        VCT.Libs.Trace.Tracer.Info("-- >VCT Tunnels");
                        for (int i = 0; i < this.Settings4VCTServer.Tunnels.Length; i++)
                        {
                            var t = this.Settings4VCTServer.Tunnels[i];
                            VCT.Libs.Trace.Tracer.Info("-- -- >#{0} [{1}]", i, t.Name);
                            VCT.Libs.Trace.Tracer.Info("-- -- ----Address : {0}", t.Address ?? "");
                            VCT.Libs.Trace.Tracer.Info("-- -- ----Ports : {0}", String.Concat(t.Ports.Select(p => p.ToString() + ',')));
                        }

                        VCT.Libs.Trace.Tracer.Info();

                        VCT.Libs.Trace.Tracer.Info("-- >VCT Device Settings");

                        if (this.Settings4VCTServer.DeviceSettings != null && this.Settings4VCTServer.DeviceSettings.Length > 0)
                        {
                            for (int i = 0; i < this.Settings4VCTServer.DeviceSettings.Length; i++)
                            {
                                VCT.Libs.Trace.Tracer.Info("-- -- >VCT DeviceSettings #{0} [{1}]", i, this.Settings4VCTServer.DeviceSettings[i].SettingsName);
                            }
                            VCT.Libs.Trace.Tracer.Info();
                        }
                    }
                    catch (System.Exception e)
                    {
                        VCT.Libs.Trace.Tracer.Info("VCT Failed to start !", e);
                    }
                }

                VCT.Libs.Trace.Tracer.Info();
            }

            #endregion

            #region modules

            CurrentSettings = Settings.ComServerSettings.Read();

            CommonBL.IBLCore _bl = null;

            if (CurrentSettings.Modules != null && CurrentSettings.Modules.Length > 0)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                VCT.Libs.Trace.Tracer.Info("->Multi CommServer Modules:");
                Console.ForegroundColor = ConsoleColor.Gray;

                var _list = new List<CommonBL.IBLCore>();
                foreach (var m in CurrentSettings.Modules)
                {
                    VCT.Libs.Trace.Tracer.Info("-- -Module #{0}", _list.Count + 1);
                    VCT.Libs.Trace.Tracer.Info("-- ----TypeName     : {0}", m.TypeName);
                    VCT.Libs.Trace.Tracer.Info("-- ----AssemblyName : {0}", m.AssemblyName);

                    try
                    {
                        VCT.Libs.Trace.Tracer.Info("--- ---Loading...");

                        _bl = Activator.CreateInstance(m.AssemblyName, m.TypeName).Unwrap() as CommonBL.IBLCore;
                        VCT.Libs.Trace.Tracer.Info("--- ---Success!");
                        _list.Add(_bl);
                    }
                    catch (Exception e)
                    {
                        VCT.Libs.Trace.Tracer.Info("- Failed!");

                        VCT.Libs.Trace.Tracer.Info("-- ----Exception : {0} : {1}", e.GetType().Name, e.Message);
                    }

                    try
                    {
                        VCT.Libs.Trace.Tracer.Info("--- ---Starting...");

                        _bl.Start(VCTServer);

                        VCT.Libs.Trace.Tracer.Info("--- ---Success!");
                    }
                    catch (Exception e)
                    {
                        VCT.Libs.Trace.Tracer.Exception("Failed to run ComServer", e);
                    }
                }

                _BlCores = _list.ToArray();

                VCT.Libs.Trace.Tracer.Info();
            }
            else
            {
                VCT.Libs.Trace.Tracer.Info("->Multi CommServer :: No Modules were found!");
            }

            #endregion

            Console.ForegroundColor = ConsoleColor.Blue;
            VCT.Libs.Trace.Tracer.Info();
            VCT.Libs.Trace.Tracer.Info("CommServer was Started!");
            Console.ForegroundColor = ConsoleColor.Gray;
        }

     
        public void Stop()
        {
            foreach (var item in _BlCores)
            {
                item.Stop();
            }
            _BlCores = null;
            //if (DigiGatewayCore != null)
            //{
            //    DigiGatewayCore.MainEventsBus.GateWayConnnection -= MainEventsBus_GateWayConnnection;
            //    DigiGatewayCore.MainEventsBus.NewNodeConnection -= MainEventsBus_NewNodeConnection;
            //    DigiGatewayCore.Stop();
            //    DigiGatewayCore = null;
            //}
            if (VCTServer != null)
            {
                VCTServer.MainEventsBus.DeviceOnIncomingEvent -= VCT_MainEventsBus_DeviceOnIncomingEvent;
                VCTServer.MainEventsBus.DeviceConnnection -= VCT_MainEventsBus_DeviceConnnection;
                VCTServer.Stop();
                VCTServer = null;
            }
        }

        #endregion

        #region DigiGatyeway events 

        //private void MainEventsBus_NewNodeConnection(object o, DIGI.APIProtocol.Events.NewEndPointConnectionEventArgs e)
        //{
        //    //VCTServer.AddDevice_Pending_ComLayer(
        //    //    e.NewEndpoint,
        //    //    this.CurrentSettings.DefaultDigiTunnel);

        //    VCTServer.AddDevice_Pending_ComLayer(e.NewEndpoint);
        //}

        //private void MainEventsBus_GateWayConnnection(object o, DIGI.APIProtocol.Events.NewGateWayConnectionEventArgs e)
        //{
        //    if (NewDigiGatewayConnected != null)
        //    {
        //        NewDigiGatewayConnected(o, e);
        //    }
        //}

        #endregion

        #region VCT core events

        private void VCT_MainEventsBus_DeviceConnnection(object o, VCT.Core.Events.DeviceConnectionEventArgs e)
        {
            if (NewDeviceConnected != null)
            {
                NewDeviceConnected(o, e);
            }

            if (_BlCores != null && e.Device.IsConnected)
            {
                foreach (var bl in _BlCores)
                {
                    if (bl.OnDeviceConnetion(e.Device))
                    {
                        e.Handled = true;
                        break;
                    }
                }
            }
        }

        private void VCT_MainEventsBus_DeviceOnIncomingEvent(object o, VCT.Core.Events.DeviceEventArgs e)
        {
        }

        #endregion
    }
}
