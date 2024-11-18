using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.DIGI.APIProtocol
{

    #region Delegate
    public delegate void PacketDelegate(object sender, PacketEventArgs e);
    #endregion

    public class PacketEventArgs : EventArgs
    {
        #region properties

        public Packets.APIPacket P { get; private set; }

        #endregion

        #region ctor(s)

        public PacketEventArgs(Packets.APIPacket p)
            : base()
        {
            P = p;
        }

        #endregion
    }
}
