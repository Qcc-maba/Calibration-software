using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Meatest M-142 multifunction calibrator, reachable over GPIB (factory
    /// address 2) or RS-232 (8-N-1, 150-19200 baud, straight 1:1 cable).
    /// <para>
    /// Claimed by the model token. <c>HardwareDeviceHost.handlePacket</c> gives this model the SN
    /// "M-142" after matching a "MEATEST" reply that names model 142, so a Meatest M-140 or M-143 on
    /// the same bus is not swept up by this core.
    /// </para>
    /// See docs/devices/electronics/Meatest-M142/protocol.md.
    /// </summary>
    public class MeatestM142BLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "M-142"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new MeatestM142BL(this);
        }
    }
}
