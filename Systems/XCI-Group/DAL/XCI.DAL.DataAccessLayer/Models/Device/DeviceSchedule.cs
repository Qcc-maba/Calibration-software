using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DeviceSchedule
    {
        public byte ScheduleTypeID { set; get; }

        public List<DeviceScheduleZone> ScheduleZone { set; get; }
    }
}
