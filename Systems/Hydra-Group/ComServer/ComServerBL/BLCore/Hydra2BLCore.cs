using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Hydra2BLCore : CommonBL.IBLCore
    {
        #region Members

        internal Core.ServerCore VCT_Server;
        private Hydra2DeviceBL bl;
        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region IBLCore Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected && device.SN.Contains("2625");
            if (isAllowed)
            {
                if ((device.BL == null) || !(device.BL is Device.Hydra2DeviceBL))
                {
                    this.bl = new Device.Hydra2DeviceBL(this);
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
            if (bl != null)
            {
                bl.Start(device);
            }
        }

        public void Start(Core.ServerCore server)
        {
            this.VCT_Server = server;
            this.DeviceSettings = Settings.HardwareBL_Settings.Read();
        }

        public void Stop()
        {

        }

        #endregion
    }
}
