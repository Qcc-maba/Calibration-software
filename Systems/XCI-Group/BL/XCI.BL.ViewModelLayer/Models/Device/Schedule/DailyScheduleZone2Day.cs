using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class DailyScheduleZone2Day
    {
        public int? Duration { get; set; }
        public int? Quantity { get; set; }

        public DailyScheduleZone2Day()
        {
            Duration = 0;
            Quantity = 0;
        }
    }
}
