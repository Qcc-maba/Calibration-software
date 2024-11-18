using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class IrrigationSchedule
    {
        public byte ScheduleType { set; get; }
        public List<IrrigationScheduleItem> ScheduleItems { set; get; }

        public IrrigationSchedule()
        {
            ScheduleItems = new List<IrrigationScheduleItem>();
        }
    }
}
