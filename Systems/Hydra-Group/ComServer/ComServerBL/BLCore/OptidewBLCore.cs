using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.CommonBL;

namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    /// <summary>
    /// BL core for the Michell Optidew hygrometer. Identified over Modbus, where the device host
    /// assigns the SN "Optidew".
    /// </summary>
    public class OptidewBLCore : BaseBLCore
    {
        protected override string DeviceIdToken
        {
            get { return "Optidew"; }
        }

        protected override BaseBLDevice CreateDeviceBL()
        {
            return new OptidewDeviceBL(this);
        }
    }
}
