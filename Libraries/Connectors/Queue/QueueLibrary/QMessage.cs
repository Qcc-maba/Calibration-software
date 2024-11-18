using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.QueueLibrary
{
    public class QMessage<T>
    {
        public T Content { get; set; }
        public string ID { get; set; }
    }
}
