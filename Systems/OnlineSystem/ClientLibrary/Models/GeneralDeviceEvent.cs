using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Online.ClientLibrary.Models
{
    public class GeneralDeviceEvent<T>
    {
        public string sn { get; set; }
        public int code { get; set; }

        public T Event { get; set; }

        public int overview { get; set; }
    }
}

