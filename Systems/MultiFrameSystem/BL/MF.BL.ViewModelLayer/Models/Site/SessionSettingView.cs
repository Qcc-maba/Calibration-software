using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SessionSettingView
    {
        public bool IsDelete { set; get; }
        public List<SessionDaySettingView> Days { get; set; }
        public long SessionID { get; set; }
        public long EraID { get; set; }
        public int SessionIndex { get; set; }
        public string Name { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public bool IsIrrigationAllowed { get; set; }
        public bool IsAutoUpdate { get; set; }
        public byte RestrictionType { get; set; }
        public long SiteID { get; set; }


        public SessionSettingView()
        {

        }

        public SessionSettingView(SessionSetting setting , List<SessionDaySetting> _Days =null)
        {
            SiteID = setting.SiteID;
            SessionID = setting.SessionID;
            EraID = setting.EraID;
            SessionIndex = setting.SessionIndex;
            Name = setting.Name;
            StartDate = setting.StartDate;
            EndDate = setting.EndDate;
            IsIrrigationAllowed = setting.IsIrrigationAllowed;
            IsAutoUpdate = setting.IsAutoUpdate;
            RestrictionType = setting.RestrictionType;

            if (_Days != null)
            {
               // Days = _Days.GroupBy(g => g.DayIndex).Select(s => new SessionDaySettingView(s.OrderBy(o => o.Time).ToArray())).ToList();
            }

        }

    }
}
