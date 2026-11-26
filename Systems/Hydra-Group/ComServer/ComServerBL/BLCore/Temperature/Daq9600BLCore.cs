using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the GW Instek DAQ-9600 (MBA-1058). HardwareDeviceHost names the instrument "DAQ-9600" when its
    /// *IDN? reply carries both the vendor and the model ("GWInstek,DAQ-9600,GEY150853,M1.07_S1.02"), ahead of the
    /// vendor-wide "Instek" branch, so the old <c>InstekBLCore</c> never claims it.
    /// See docs/devices/temperature/GW-Instek-DAQ-9600/protocol.md.
    /// </summary>
    public class Daq9600BLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "DAQ-9600"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new Daq9600BL(this);
        }
    }
}
