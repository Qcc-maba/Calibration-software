using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class DailyScheduleGorupView
    {
        public int DayIndex { get; set; }

        public List<ScheduleTime> ScheduleStartTime { get; set; }

        public DailyScheduleGorupView()
        {
            DayIndex = -1;
        }
    }
}
