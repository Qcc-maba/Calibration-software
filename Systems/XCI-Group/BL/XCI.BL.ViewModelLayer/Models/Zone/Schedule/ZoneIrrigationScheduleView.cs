using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone.Schedule
{
    public class ZoneIrrigationScheduleView : BaseZoneScheduleView
    {
        public ZoneIrrigationScheduleRow[] Rows { get; set; }
        public ScheduleDayView[] TitleDays { get; set; }

        /// <summary>
        /// ReadOnly
        /// </summary>
        public int TotalWeeklyMinutes { get; set; }
        /// <summary>
        /// ReadOnly
        /// </summary>
        public int TotalWeeklyDays { get; set; }


        
    }
}
