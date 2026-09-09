using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Fluke 5322A multifunction electrical tester calibrator, reachable over GPIB,
    /// RS-232 or USB (a virtual COM port, 8-N-1).
    /// <para>
    /// Claimed by the MODEL token, not the vendor: the Fluke Hydra loggers and the 5522A calibrator
    /// also answer "FLUKE,...", so a vendor-level token would collide with both.
    /// </para>
    /// <para>
    /// ⚠️ The instrument reports EITHER "FLUKE,5322A,..." or "FLUKE,5320A,..." depending on the
    /// 5320A-emulation menu setting, so <c>HardwareDeviceHost.handlePacket</c> matches both and
    /// normalises them to the single SN "5322A" that this token expects. Without that normalisation,
    /// flipping a menu on the front panel would take the instrument out of the server with no error.
    /// </para>
    /// See docs/devices/electronics/Fluke-5322A/protocol.md.
    /// </summary>
    public class Fluke5322aBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "5322A"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Fluke5322aBL(this);
        }
    }
}
