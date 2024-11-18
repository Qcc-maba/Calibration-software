using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.DIGI.APIProtocol.Events
{
    public class EventsBusDigi
    {
        public delegate void GateWayConnnectionDelegate(object o, NewGateWayConnectionEventArgs e);
        public event GateWayConnnectionDelegate GateWayConnnection;

        public delegate void NewNodeConnectionDelegate(object o, NewEndPointConnectionEventArgs e);
        public event NewNodeConnectionDelegate NewNodeConnection;


        public void Fire_NewGateWay_Event(object o, Events.NewGateWayConnectionEventArgs e)
        {
            if (GateWayConnnection != null)
            {
                GateWayConnnection(o, e);
            }
        }
        public void Fire_New_Node_Connection(object o, NewEndPointConnectionEventArgs e)
        {
            if (NewNodeConnection != null)
            {
                NewNodeConnection(o, e);
            }
        }
    }
}
