using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Online.ClientLibrary.Models
{
    public class DeviceStatus
    {
        public bool Status { get; set; }

        public bool Connection { get; set; }
        public bool IsIrrigating { get; set; }
        public bool IsFertilizing { get; set; }
        public bool IsFailure { get; set; }
    }
}
