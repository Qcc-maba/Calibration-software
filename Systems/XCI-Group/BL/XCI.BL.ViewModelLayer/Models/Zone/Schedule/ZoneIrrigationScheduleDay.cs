using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone.Schedule
{
    public class ZoneIrrigationScheduleDay
    {
        public int Day { get; set; }
        public int? Duration { get; set; }
        public int? Quantity { get; set; }
    }
}
