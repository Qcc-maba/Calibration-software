using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class FlowSensorSettings
    {


        public byte SensorType { get; set; }

        public bool IsEnabled { get; set; }
        public int? SensorInputNumber { get; set; }

        public decimal Pulse_PulseSize { get; set; }
        public int Pulse_PulseType { get; set; }

        public decimal DI_KValue { get; set; }
        public decimal DI_OffsetValue { get; set; }
    }
}
