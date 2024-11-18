using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class WeeklyScheduleZone2Day
    {
        //public bool IsAllowedDay { get; set; }
        public int? Duration { get; set; }
        public int? Quantity { get; set; }

        public WeeklyScheduleZone2Day()
        {
            Duration = 0;
            Quantity = 0;
        }
    }
}
