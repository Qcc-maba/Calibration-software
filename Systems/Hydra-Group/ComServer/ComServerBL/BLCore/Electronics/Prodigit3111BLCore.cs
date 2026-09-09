using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the PRODIGIT 3111 DC electronic load, reached over RS-232 at 115200 baud.
    /// Identified by the whole *IDN? reply, which is just the model token: "PRODIGIT_3111".
    /// See docs/devices/electronics/Prodigit-3111/protocol.md.
    /// </summary>
    public class Prodigit3111BLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "PRODIGIT_3111"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Prodigit3111BL(this);
        }
    }
}
