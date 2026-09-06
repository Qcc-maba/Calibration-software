using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Siglent SDG6052X arbitrary waveform generator, reached over USBTMC.
    /// Identified by the "SDG6052X" model token in the *IDN? reply
    /// ("Siglent Technologies,SDG6052X,SDG6XEBD4R0879,6.01.01.35R5B1").
    /// See docs/devices/electronics/Siglent-SDG6052X/protocol.md.
    /// </summary>
    public class Sdg6052xBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "SDG6052X"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Sdg6052xBL(this);
        }
    }
}
