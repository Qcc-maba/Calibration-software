using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Settings
{
    public class UserValidatorSettings
    {
        #region properties

        // Summary:
        //     Only allow [A-Za-z0-9@_] in UserNames
        public bool AllowOnlyAlphanumericUserNames { get; set; }

        #endregion

        #region ctor

        public UserValidatorSettings()
        {
            AllowOnlyAlphanumericUserNames = false;
        }

        #endregion
    }
}
