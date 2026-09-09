using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Datron/Wavetek 9100 multifunction calibrator, connected over GPIB and used as a
    /// master reference for electronics calibration. Matched on the "Datron9100" SN token set by the
    /// device host once the instrument is identified.
    /// </summary>
    public class Datron9100BLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "Datron9100"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Datron9100BL(this);
        }
    }
}
