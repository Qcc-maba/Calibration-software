using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DeviceAccumulator
    {
        public long ID { get; set; }
        public string AccType { get; set; }
        public long DeviceID { get; set; }


        public string Start_Value { get; set; }
        public long? StartTicks { get; set; }
        public DateTime? StartDateTimeView
        {
            get
            {
                return StartTicks.HasValue ? new DateTime(StartTicks.Value) : (DateTime?)null;
            }
        }

        public string End_Value { get; set; }
        public long? EndTicks { get; set; }
        public DateTime? EndDateTimeView
        {
            get
            {
                return EndTicks.HasValue ? new DateTime(EndTicks.Value) : (DateTime?)null;
            }
        }

        public DeviceAccumulator()
        {
            ID = -1;
        }
    }
}
