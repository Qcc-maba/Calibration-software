using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{

    public interface IProtocolParser
    {
        PacketDelegate OnPacket { get; set; }
        void OnData(byte[] buffer, int offset, int count);
    }
}
