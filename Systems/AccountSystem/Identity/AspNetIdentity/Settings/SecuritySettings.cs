using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class SecuritySettings
    {
        public bool UserLockoutEnabledByDefault { get; set; }
        public int DefaultAccountLockout { get; set; }
        public TimeSpan DefaultAccountLockoutTimeSpan
        {
            get
            {
                return TimeSpan.FromMilliseconds(DefaultAccountLockout);
            }
        }

        public int MaxFailedAccessAttemptsBeforeLockout { get; set; }

        public SecuritySettings()
        {
            UserLockoutEnabledByDefault = true;
            DefaultAccountLockout = (int)TimeSpan.FromMinutes(5).TotalMilliseconds;
            MaxFailedAccessAttemptsBeforeLockout = 5;
        }
    }
}
