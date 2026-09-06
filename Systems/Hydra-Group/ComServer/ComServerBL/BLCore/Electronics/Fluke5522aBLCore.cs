using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Fluke 5522A multi-product calibrator, reached over RS-232 at 9600 baud.
    /// <para>
    /// Claimed by the MODEL token, not the vendor: the Fluke Hydra loggers also answer "FLUKE,..."
    /// (as "FLUKE,2625A" / "FLUKE,2638A"), so a vendor-level token would collide with them.
    /// <c>HardwareDeviceHost.handlePacket</c> gives this model the SN "5522A".
    /// </para>
    /// See docs/devices/electronics/Fluke-5522A/protocol.md.
    /// </summary>
    public class Fluke5522aBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "5522A"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Fluke5522aBL(this);
        }
    }
}
