using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone.Schedule
{
    public class ZoneIrrigationScheduleDailyView : BaseZoneScheduleView
    {
       // public ScheduleDayTitle Day { get; set; }
        public DailyStartTime[] StartTimes { get; set; }

       // public DailyScheduleZone DailyScheduleZone { get; set; }


    }
}
