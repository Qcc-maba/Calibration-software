using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>BL core for the Fluke Hydra 2638A logger family.</summary>
    public class Hydra3BLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "2638"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Hydra3DeviceBL(this);
        }
    }
}
