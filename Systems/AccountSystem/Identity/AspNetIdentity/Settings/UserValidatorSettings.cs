using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class UserValidatorSettings
    {
        public bool AllowOnlyAlphanumericUserNames { get; set; }
        public bool RequireUniqueEmail { get; set; }

        public UserValidatorSettings()
        {
            AllowOnlyAlphanumericUserNames = false;
            RequireUniqueEmail = true;
        }
    }
}
