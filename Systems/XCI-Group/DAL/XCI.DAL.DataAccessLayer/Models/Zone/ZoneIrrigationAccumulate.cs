using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone
{
    public class ZoneIrrigationAccumulate
    {

        public int? MaxCycleTime { get; set; }

        /// <summary>
        /// (Seconds)
        /// </summary>
        public int? MaxSoakTime { get; set; }
        public byte ScheduleTypeID { get; set; }
        public int Current_TotalWeeklyMinutes { get; set; }

        public int Current_RunTimeDaily { get; set; }
        public byte Current_WateringDays { get; set; }
    }
}
