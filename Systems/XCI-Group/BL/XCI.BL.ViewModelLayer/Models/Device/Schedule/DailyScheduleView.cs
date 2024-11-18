using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class DailyScheduleView : BaseDeviceScheduleView
    {
        public ScheduleDayTitle Day { get; set; }
        public DailyStartTime[] StartTimes { get; set; }

        public DailyScheduleZone[] Zones { get; set; }


        public DailyScheduleView()
        {

        }

    }
}
