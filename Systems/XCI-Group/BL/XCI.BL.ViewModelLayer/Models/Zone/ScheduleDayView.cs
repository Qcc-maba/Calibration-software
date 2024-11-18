using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class ScheduleDayView
    {
        /// <summary>
        /// [1..7] = [Sun..Sat]
        /// </summary>
        public byte DayNumber { get; set; }

        public bool IsAllowedDay { get; set; }
    }
}
