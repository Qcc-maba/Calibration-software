using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    #region Delegate

    public delegate void PacketDelegate(object sender, PacketEventArgs e);

    #endregion

    public class PacketEventArgs : EventArgs
    {

        #region properties

        public Common.IPacket P { get; private set; }

        #endregion

        #region ctor(s)

        public PacketEventArgs(Common.IPacket p)
            : base()
        {
            P = p;
        }

        #endregion
    }
}
