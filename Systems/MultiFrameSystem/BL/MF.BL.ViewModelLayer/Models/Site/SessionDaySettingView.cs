using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SessionDaySettingView
    {
        public long ParentSessionID { get; set; }
        public int DayIndex { get; set; }
        public string Name { get; set; }
        public bool IsIrrigationAllowed { get; set; }

        public int MaxDailyIrrigrationSeconds { get; set; }
        public int MaxDailyCycles { get; set; }

        public List<TimeValueView> Times { get; set; }

        public SessionDaySettingView()
        {

        }

        private bool IrrigationAllowed(SessionDaySetting[] setting)
        {
            return setting.All(u => u.IrrigationAllowed);
        }
    }
}
