using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class SystemTemperatureUnit
    {
        public int TypeUnitID { get; set; }
        public string DisplayName { get; set; }
        public string DisplayUnit { get; set; }
        public bool IsDefault { get; set; }
    }
}
