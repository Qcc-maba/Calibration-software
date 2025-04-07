using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;

namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    public class OptidewBLCore : CommonBL.IBLCore
    {
        #region Members

        internal Core.ServerCore VCT_Server;
        private OptidewDeviceBL bl;

        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region Public Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.SN.Contains("Optidew") && device.IsConnected;
            if (isAllowed)
            {
                if ((device.BL == null) || !(device.BL is OptidewDeviceBL))
                {
                    this.bl = new OptidewDeviceBL(this);
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
