using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class WeeklyScheduleZone
    {
        public int ZoneNumber { get; set; }
        public string Name { get; set; }
        public WeeklyScheduleZone2Day[] Days { get; set; }
    }
}
