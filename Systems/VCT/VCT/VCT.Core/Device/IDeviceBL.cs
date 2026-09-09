using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace Maba.VCT.Core.Device
{
    /// <summary>
    /// The business logic attached to one device host — it drives the instrument (init, configure,
    /// acquire) and reacts to incoming packets. Implemented by CommonBL.BaseBLDevice.
    /// </summary>
    public interface IDeviceBL
    {
        void Start(IDeviceHost device);
        void OnTimer();
        bool OnConnection(bool state);
        void OnEvent(Events.DeviceEventArgs e);

    }
}
