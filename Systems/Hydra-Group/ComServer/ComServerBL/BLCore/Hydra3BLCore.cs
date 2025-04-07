using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.WebSockets;
using System.Runtime;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Hydra3BLCore : CommonBL.IBLCore
    {
        #region Members

        internal Core.ServerCore VCT_Server;
        private Hydra3DeviceBL bl;

        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion
        
        #region Public Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.SN.Contains("2638") && device.IsConnected;
            if (isAllowed)
            {
                if ((device.BL == null) || !(device.BL is Device.Hydra3DeviceBL))
                {
                    this.bl = new Device.Hydra3DeviceBL(this);
                    device.BL = this.bl;
                    bl.Start(device);
                }
            }
            return (isAllowed);
        }
        public void OnEvent(DeviceEventArgs e)
        {
            if (bl != null)
            {
                bl.OnEvent(e);
            }
        }
        public void OnWebSocketDeviceConnetion(WebSocketDeviceHost device)
        {
            bl.Start(device);
        }
        public void Start(ServerCore server)
        {
            this.VCT_Server = server;
            this.DeviceSettings = HardwareBL_Settings.Read();
        }
        public void Stop()
        {
        }

        #endregion
    }
}
