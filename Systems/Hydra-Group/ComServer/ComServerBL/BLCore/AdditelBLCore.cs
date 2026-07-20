using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    /// <summary>BL core for Additel pressure instruments (identified by the "TAU" token).</summary>
    public class AdditelBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "TAU"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new AdditelBL(this);
        }
    }
}
