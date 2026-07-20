using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    /// <summary>BL core for TTi (Thurlby Thandar) instruments.</summary>
    public class TTIBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "TTI"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new TTIDeviceBL(this);
        }
    }
}
