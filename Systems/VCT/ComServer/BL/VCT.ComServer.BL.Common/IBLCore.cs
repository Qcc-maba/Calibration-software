using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.CommonBL
{
    /// <summary>
    /// A pluggable business-logic module for one instrument FAMILY (Hydra, Agilent, TTI, ...).
    /// The server offers every newly identified device to each loaded core; the core claims the
    /// device if the serial number matches its family and attaches a per-device BL. Modules are
    /// listed in ComServerSettings.Modules and loaded by reflection.
    /// </summary>
    public interface IBLCore
    {
        void Start(Core.ServerCore server);
        void Stop();
        bool OnDeviceConnetion(HardwareDeviceHost dev);
        void OnEvent(DeviceEventArgs e);
        void OnWebSocketDeviceConnetion(WebSocketDeviceHost device);
    }
}
