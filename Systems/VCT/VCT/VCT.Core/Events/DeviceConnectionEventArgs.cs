using Maba.VCT.Core.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Events
{
    public class DeviceConnectionEventArgs : EventArgs
    {
        public bool Handled { get; set; } = false;
        public Device.IDeviceHost Device { get; private set; }

        public DeviceConnectionEventArgs(IDeviceHost device)
        {
            this.Device = device;
        }
    }
}
