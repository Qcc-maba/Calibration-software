using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class PasswordValidatorSettings
    {
        public bool RequireDigit { get; set; }
        public int RequiredLength { get; set; }
        public bool RequireLowercase { get; set; }
        public bool RequireNonLetterOrDigit { get; set; }
        public bool RequireUppercase { get; set; }

        public PasswordValidatorSettings()
        {
            RequiredLength = 6;

            RequireDigit = true;
            RequireNonLetterOrDigit = false;
            RequireLowercase = false;
            RequireUppercase = false;
        }
    }
}
