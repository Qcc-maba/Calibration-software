using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.StorageLibrary
{
    public class StorageGenerator
    {
        public Func<IStorageConnector> Generate_StorageConnector { get; set; }
    }
}
