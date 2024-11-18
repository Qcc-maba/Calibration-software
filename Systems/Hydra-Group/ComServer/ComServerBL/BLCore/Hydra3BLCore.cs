using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Hydra3BLCore : CommonBL.IBLCore
    {
        #region Members

        private Core.ServerCore VCT_Server;

        #endregion

        #region properties

        public HydraBL_Settings DeviceSettings { get; private set; }

        #endregion

        public bool OnDeviceConnetion(DeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.SN.Contains("2638") && device.IsConnected;
            if (isAllowed)
            {
                if ((device.BL == null) || !(device.BL is Device.Hydra3DeviceBL))
                {
                    var bl = new Device.Hydra3DeviceBL(this);
                    bl.Start(device);
                }
            }
            return (isAllowed);
        }

        public void Start(ServerCore server)
        {
            this.VCT_Server = server;
            this.DeviceSettings = HydraBL_Settings.Read();
        }

        public void Stop()
        {
        }
    }
}
