using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device
{
    public class VCTTunnel0
    {
        public ComLayer.Tunnel Tunnel { get; private set; }

        public VCTDeviceSettings DeviceSettings { get; private set; }

        public VCTTunnel0(ComLayer.Tunnel tunnel, VCTDeviceSettings settings)
        {
            this.Tunnel = tunnel;
            this.DeviceSettings = settings;
        }
    }
}
