using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    public class IdentificationInfo
    {
        public byte[] SN { get; set; }

        public Version AppVersion { get; set; }
        public Version App2Version { get; set; }
        public Version DeviceModel { get; set; }

        public ushort MaxPacketSize { get; set; }

        public IdentificationInfo()
        {

        }
        public IdentificationInfo(string sn)
        {
            this.SN = sn.Select(s => (byte)s).ToArray();
        }
    }
}
