using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device
{
    class DeviceHostPending
    {
        public bool Remove { get; set; }
        //public bool Immigrated2DevicesList { get; set; }

        public int TotalAwakeConnectPackets { get; set; }
        public DateTime? LastAwakeConnectPacket { get; set; }

        public IDeviceHost D { get; set; }
    }
}
