using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the GW Instek DAQ-9600 (MBA-1058). HardwareDeviceHost names the instrument "DAQ-9600_&lt;serial&gt;"
    /// (one BL per unit; the token below is contained in it) when its *IDN? reply carries both the vendor and the
    /// model ("GWInstek,DAQ-9600,GEY150853,M1.07_S1.02"), ahead of the vendor-wide "Instek" branch, so the old
    /// <c>InstekBLCore</c> never claims it.
    /// <para>
    /// Two units on one station get a BL each, but share the one Daq9600 settings family: the same channel list,
    /// sensor type and interval, and the operator's Confirm configures both.
    /// </para>
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
