using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    /// <summary>
    /// BL core for the Keysight InfiniiVision EDUX1002A oscilloscope (1000 X-Series, 50 MHz,
    /// 2 analog channels). Identified by the "EDUX1002A" model token in the *IDN? reply
    /// ("KEYSIGHT TECHNOLOGIES,EDUX1002A,&lt;serial&gt;,X.XX.XX").
    /// See docs/devices/electronics/Keysight-EDUX1002A/protocol.md.
    /// </summary>
    public class KeysightEdux1002aBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "EDUX1002A"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new KeysightEdux1002aBL(this);
        }
    }
}
