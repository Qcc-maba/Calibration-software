using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.DIGI.APIProtocol.Events
{
    public class NewEndPointConnectionEventArgs : EventArgs
    {
        public RemoteEndpoint NewEndpoint { get; private set; }

        public NewEndPointConnectionEventArgs(RemoteEndpoint newEndpoint)
        {
            this.NewEndpoint = newEndpoint;
        }
    }
}
