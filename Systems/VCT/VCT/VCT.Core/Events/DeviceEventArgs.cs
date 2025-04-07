using Maba.VCT.Common;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Events
{
    public class DeviceEventArgs : EventArgs
    {

        public Device.IDeviceHost Device { get; private set; }
        public IPacket Packet { get; private set; }

        public DeviceEventArgs(Device.IDeviceHost device, IPacket packet)
        {
            this.Device = device;
            this.Packet = packet;
        }
    }
}
