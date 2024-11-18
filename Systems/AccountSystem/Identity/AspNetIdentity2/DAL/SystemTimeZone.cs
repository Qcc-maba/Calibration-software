using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class SystemTimeZone
    {
        public int ZoneID { get; set; }
        public string SystemZoneID { get; set; }
        public string DisplayName { get; set; }
        public string DaylightName { get; set; }
        public string StandardName { get; set; }
        public int GMTOffset { get; set; }
        public int ManualOffset { get; set; }
        public bool IsDefault { get; set; }
        public bool IsDaylightTime { get; set; }

    }
}
