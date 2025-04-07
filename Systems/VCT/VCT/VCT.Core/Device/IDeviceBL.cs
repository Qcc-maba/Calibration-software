using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace Maba.VCT.Core.Device
{
    public interface IDeviceBL
    {
        void Start(IDeviceHost device);
        void OnTimer();
        bool OnConnection(bool state);
        void OnEvent(Events.DeviceEventArgs e);

    }
}
