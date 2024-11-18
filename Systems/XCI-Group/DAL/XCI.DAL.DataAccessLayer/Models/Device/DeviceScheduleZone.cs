using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DeviceScheduleZone
    {
        public int ZoneNum { set; get; }
        public int DayNum { set; get; }
        public int StartTime { set; get; }
        public int Quantity { set; get; }
        public int Time { set; get; }
    }
}
