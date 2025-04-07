using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
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
        bool OnDeviceConnetion(HardwareDeviceHost dev);
        void OnEvent(DeviceEventArgs e);
        void OnWebSocketDeviceConnetion(WebSocketDeviceHost device);
    }
}
