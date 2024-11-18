using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Events
{
    public class DeviceEventArgs : EventArgs
    {

        public Device.DeviceHost Device { get; private set; }
        public byte Type { get; set; }
        public byte SubType { get; set; }
        public byte[] Data { get; set; }

        public DeviceEventArgs(Device.DeviceHost device)
        {
            this.Device = device;
        }
    }
}
