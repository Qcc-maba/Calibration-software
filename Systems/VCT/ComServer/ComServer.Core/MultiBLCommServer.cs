using Maba.VCT.Core.Device;
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

        public delegate void NewDeviceConnectedDelegate(object o, VCT.Core.Events.DeviceConnectionEventArgs e);
        public event NewDeviceConnectedDelegate NewDeviceConnected;

        public delegate void NewEventDelegate(object o, VCT.Core.Events.DeviceEventArgs e);
        public event NewEventDelegate NewEvent;

        #endregion

        #region public methods

        /// <param name="deferHardwareIdentificationUntilEnabled">
        /// When true (interactive console host), pending devices do not get *IDN? until <see cref="EnableHardwareIdentification"/> is called after operator OK.
        /// </param>
        public void Start(bool deferHardwareIdentificationUntilEnabled = false)
        {
            Console.ForegroundColor = ConsoleColor.Blue;
            VCT.Libs.Trace.Tracer.Info("CommServer - Starting....");
            Console.ForegroundColor = ConsoleColor.Gray;

            #region VCT

            this.Settings4VCTServer = VCT.Core.Settings.VCTSettings.Read();
            CalibratorLoggerSettingsFromDb.TryApplyToVctSettings(this.Settings4VCTServer);

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
                        VCTServer.MainEventsBus.WebsocketDeviceConnnection += MainEventsBus_WebsocketDeviceConnnection;
                        VCTServer.MainEventsBus.AutoHandleNewDevices = true;
                        VCTServer.DeferHardwareIdentificationPackets = deferHardwareIdentificationUntilEnabled;
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

            #region Modules

            CurrentSettings = Settings.ComServerSettings.Read();

            if (CurrentSettings.Modules != null && CurrentSettings.Modules.Length > 0)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                VCT.Libs.Trace.Tracer.Info("->Multi CommServer Modules:");
                Console.ForegroundColor = ConsoleColor.Gray;

                var _list = new List<CommonBL.IBLCore>();
                foreach (var m in CurrentSettings.Modules)
                {
                    CommonBL.IBLCore loaded = null;
                    try
                    {
                        loaded = Activator.CreateInstance(m.AssemblyName, m.TypeName).Unwrap() as CommonBL.IBLCore;
                        if (loaded == null)
                        {
                            VCT.Libs.Trace.Tracer.Info("- Failed! Module does not implement IBLCore or activation returned null (Type={0}).", m.TypeName);
                            continue;
                        }

                        _list.Add(loaded);
                    }
                    catch (Exception e)
                    {
                        VCT.Libs.Trace.Tracer.Info("- Failed!");
                        VCT.Libs.Trace.Tracer.Info("-- ----Exception : {0} : {1}", e.GetType().Name, e.Message);
                        continue;
                    }

                    try
                    {
                        loaded.Start(VCTServer);
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

        /// <summary>After operator confirmation in console mode — starts *IDN? / identification polling for pending hardware.</summary>
        public void EnableHardwareIdentification()
        {
            VCTServer?.EnableHardwareIdentification();
        }

        public void Stop()
        {
            if (_BlCores != null)
            {
                foreach (var item in _BlCores)
                {
                    if (item == null) continue;
                    try
                    {
                        item.Stop();
                    }
                    catch (Exception e)
                    {
                        VCT.Libs.Trace.Tracer.Exception("Failed to stop BL module", e);
                    }
                }

                _BlCores = null;
            }

            if (VCTServer != null)
            {
                VCTServer.MainEventsBus.DeviceOnIncomingEvent -= VCT_MainEventsBus_DeviceOnIncomingEvent;
                VCTServer.MainEventsBus.DeviceConnnection -= VCT_MainEventsBus_DeviceConnnection;
                VCTServer.MainEventsBus.WebsocketDeviceConnnection -= MainEventsBus_WebsocketDeviceConnnection;
                VCTServer.Stop();
                VCTServer = null;
            }
        }

        #endregion


        #region VCT core events

        private void MainEventsBus_WebsocketDeviceConnnection(object o, VCT.Core.Events.DeviceConnectionEventArgs e)
        {
            if (_BlCores != null && e.Device.IsConnected)
            {
                foreach (var bl in _BlCores)
                {
                    bl.OnWebSocketDeviceConnetion(e.Device as WebSocketDeviceHost);
                }
            }
        }


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
                    if (bl.OnDeviceConnetion(e.Device as HardwareDeviceHost))
                    {
                        e.Handled = true;
                        break;
                    }
                }
            }
        }

        private void VCT_MainEventsBus_DeviceOnIncomingEvent(object o, VCT.Core.Events.DeviceEventArgs e)
        {

            if (_BlCores != null && e.Device.IsConnected)
            {
                foreach (var bl in _BlCores)
                {
                    bl.OnEvent(e);
                }
            }
        }

        #endregion
    }
}
