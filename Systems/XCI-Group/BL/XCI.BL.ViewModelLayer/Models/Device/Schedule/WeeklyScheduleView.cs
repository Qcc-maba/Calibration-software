using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class WeeklyScheduleView : BaseDeviceScheduleView
    {
        public ScheduleDayTitle [] TitleDays { get; set; }
        public WeeklyScheduleZone[] Zones { get; set; }


        public WeeklyScheduleView()
        {

        }

        

    }
}
