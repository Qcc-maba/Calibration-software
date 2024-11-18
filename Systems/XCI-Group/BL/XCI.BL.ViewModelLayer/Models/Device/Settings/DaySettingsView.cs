using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class DaySettingsView
    {
        public int DayIndex { get; set; }

        public int MaxDailyIrrigrationSeconds { get; set; }
        public int MaxDailyCycles { get; set; }

        public string Name { get; set; }

        public List<TimeValueItem> Times { get; set; }

        public bool IsIrrigationAllowed
        {
            get
            {
                if (Times != null)
                {
                    return Times.All(u => u.Allowed);
                }
                else
                {
                    return true;
                }
            }
        }

        public DaySettingsView()
        {

        }
    }
}
