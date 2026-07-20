using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Agilent/Keysight 34401A multimeter. Identified by the "HEWLETT" token in the
    /// *IDN? reply ("HEWLETT-PACKARD,34401A,..."). See docs/devices/Agilent-34401A/protocol.md.
    /// </summary>
    public class Agilent34401aBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "HEWLETT"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Agilent34401aBL(this);
        }
    }
}
