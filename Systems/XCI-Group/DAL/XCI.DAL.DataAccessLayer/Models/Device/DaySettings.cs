using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DaySettings
    {

        public DaySettings()
        {
           
        }


        public byte DayIndex { get; set; }
      
        public int MaxDailyIrrigrationSeconds { get; set; }
        public int MaxDailyCycles { get; set; }

        public string Name { get; set; }

        public int Time { get; set; }

        public bool IrrigationAllowed { get; set; }

    }
}
