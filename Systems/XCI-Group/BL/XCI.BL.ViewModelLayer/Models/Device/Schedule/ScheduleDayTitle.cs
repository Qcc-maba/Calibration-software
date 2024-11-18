using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class ScheduleDayTitle
    {
        public int DayNumber { get; set; }
        public DaySettingsView SettingsView { get; set; }
        
        public byte NumOfStartTime { get; set; }
        public int FirstStartTime { get; set; }

        public ScheduleDayTitle()
        {
            FirstStartTime = -1;
        }
    }
}
