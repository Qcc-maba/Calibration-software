using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Timers;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Hydra2BLCore : CommonBL.IBLCore
    {
        #region Members

        private Core.ServerCore VCT_Server;

        #endregion

        #region properties

        public HydraBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region IBLCore Methods

        public bool OnDeviceConnetion(Core.Device.DeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected && device.SN.Contains("2625");
            if (isAllowed)
            {
                if ((device.BL == null) || !(device.BL is Device.Hydra2DeviceBL))
                {
                    var bl = new Device.Hydra2DeviceBL(this);
                    bl.Start(device);
                }
            }
            return (isAllowed);
        }
        public void Start(Core.ServerCore server)
        {
            this.VCT_Server = server;
            this.DeviceSettings = Settings.HydraBL_Settings.Read();
        }

        public void Stop()
        {

        }

        #endregion
    }
}
