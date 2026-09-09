using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the HP 53181A frequency counter, reached over GPIB.
    /// <para>
    /// Claimed by the MODEL token, not the vendor: the counter answers
    /// "HEWLETT-PACKARD,53181A,0,3703" and the 34401A multimeter answers "HEWLETT-PACKARD,34401A,...",
    /// so <see cref="Agilent34401aBLCore"/>'s "HEWLETT" token would otherwise claim this instrument
    /// and drive it with multimeter commands. <c>HardwareDeviceHost.handlePacket</c> gives this model
    /// the SN "53181A" specifically so the two cannot be confused.
    /// </para>
    /// See docs/devices/electronics/HP-53181A/protocol.md.
    /// </summary>
    public class Hp53181aBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "53181A"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Hp53181aBL(this);
        }
    }
}
