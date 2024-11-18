using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class UserLoginInfo
    {
        #region properties

        public string LoginProvider { get; set; }
        public string ProviderKey { get; set; }

        #endregion

        #region ctors

        public UserLoginInfo(string loginProvider, string providerKey)
        {
            LoginProvider = loginProvider;
            ProviderKey = providerKey;
        }

        public UserLoginInfo()
        {

        }

        #endregion
    }
}
