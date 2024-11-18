using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DeviceInfo
    {
        public string SN { get; set; }
        public long DeviceID { get; set; }
        public int ModelID { get; set; }
        public string ModelName { get; set; }
        public DeviceAccumulator[] Accumulators { get; set; }
    }
}
