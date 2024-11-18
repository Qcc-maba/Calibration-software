using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class DeviceAccumulator
    {
        public long ID { get; set; }
        public long DeviceID { get; set; }
        public string AccType { get; set; }
        
        public string Point1_Value { get; set; }
        public string Point2_Value { get; set; }

        public long EndTicks { get; set; }
        public long? StartTicks { get; set; }

        public DateTime EndPoint { get{return new DateTime(EndTicks);}  }
        public DateTime? StartPoint { 
            get { 
                DateTime? d = null;
                 d=  (StartTicks.HasValue ? new DateTime(StartTicks.Value): d) ;
              return d;
        }
        }

    }
}
