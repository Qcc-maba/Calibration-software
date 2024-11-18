using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone.Schedule
{
    public class ZoneIrrigationScheduleRow
    {
        //seconds since midnight
        public int Time { get; set; }
        public ZoneIrrigationScheduleDay[] Days { get; set; }
    }
}
