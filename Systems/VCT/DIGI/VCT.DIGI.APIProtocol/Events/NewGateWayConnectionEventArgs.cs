using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.DIGI.APIProtocol.Events
{
    public class NewGateWayConnectionEventArgs : EventArgs
    {
        public APIProtocol Gateway { get; private set; }


        public NewGateWayConnectionEventArgs(APIProtocol gateway)
        {
            this.Gateway = gateway;
        }
    }
}
