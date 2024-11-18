using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone
{
    public class ZoneIrrigationSettings
    {
        public string WireColor { get; set; }

        public bool IsEnabled { get; set; }
        /// <summary>
        /// (%Percent)
        /// </summary>
        public int IrrigationFactor { get; set; }

        public bool UserWeatherAlgorithm { get; set; }

        /// <summary>
        /// (Seconds)
        /// </summary>


        public int? MaxCycleTime { get; set; }

        /// <summary>
        /// (Seconds)
        /// </summary>
        public int? MaxSoakTime { get; set; }

        public int Current_TotalWeeklyMinutes { get; set; }
        public byte Current_WateringDays { get; set; }
    }
}
