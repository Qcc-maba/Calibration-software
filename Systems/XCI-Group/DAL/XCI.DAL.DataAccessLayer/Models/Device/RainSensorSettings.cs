using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class RainSensorSettings
    {

        public byte SensorType { get; set; }

        public bool IsEnabled { get; set; }

        public int RainOffMinDuration { get; set; }
        public int RainStabilitySecTime { get; set; }

        public int? SensorInputNumber { get; set; }
    }
}
