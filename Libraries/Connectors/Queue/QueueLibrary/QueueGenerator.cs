using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.QueueLibrary
{
    public class QueueGenerator
    {
        public Func<IQueueConnector> Generate_IQueueConnector { get; set; }
    }
}
