using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.CommServer.CommonBL;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;


namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    public class AdditelBLCore : IBLCore
    {
        #region Members

        public Core.ServerCore VCT_Server;
        private AdditelBL bl;
        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region IBLCore Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected && device.SN.Contains("TAU");
            if (isAllowed)
            {
                if ((device.BL == null) || !(device.BL is AdditelBLCore))
                {
                    this.bl = new AdditelBL(this);
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

        public void Start(Core.ServerCore server)
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
