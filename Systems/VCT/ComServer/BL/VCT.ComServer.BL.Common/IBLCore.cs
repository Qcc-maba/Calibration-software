using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.CommonBL
{
    public interface IBLCore
    {
        void Start(Core.ServerCore server);
        void Stop();
        bool OnDeviceConnetion(Core.Device.DeviceHost dev);

    }
}
