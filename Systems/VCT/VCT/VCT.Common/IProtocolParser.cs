using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{

    public interface IProtocolParser
    {
        //Action<object, PacketEventArgs> OnPacket { get; set; }

        void OnData(byte[] buffer, int offset, int count);
        void ParsePackets();

    }
}
