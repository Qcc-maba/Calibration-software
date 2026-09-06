using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Pendulum CNT-90 timer/counter/analyzer, reached over GPIB.
    /// Identified by the "CNT-90" model token in the *IDN? reply
    /// ("PENDULUM, CNT-90, 938636, V1.14 28 Jun 2006").
    /// See docs/devices/electronics/Pendulum-CNT-90/protocol.md.
    /// </summary>
    public class Cnt90BLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "CNT-90"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Cnt90BL(this);
        }
    }
}
