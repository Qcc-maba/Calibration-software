using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    /// <summary>BL core for GW Instek instruments.</summary>
    public class InstekBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "Instek"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new InstekDeviceBL(this);
        }
    }
}
