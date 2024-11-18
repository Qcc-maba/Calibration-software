using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class SessionSetting
    {
        public long SiteID { get; set; }
        public long SessionID { get; set; }
        public long EraID { get; set; }
        public int SessionIndex { get; set; }
        public string Name { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public bool IsIrrigationAllowed { get; set; }
        public bool IsAutoUpdate { get; set; }
        public byte RestrictionType { get; set; }

    }
}
