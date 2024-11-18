using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager
{
    public class UserLogin
    {
        #region properties

        public string UserId { get; set; }
        public string LoginProvider { get; set; }
        public string ProviderKey { get; set; }

        #endregion

        #region ctor(s)

        public UserLogin(string userId, string loginProvider, string providerKey)
        {
            UserId = userId;
            LoginProvider = loginProvider;
            ProviderKey = providerKey;
        }

        public UserLogin()
        {

        }
        #endregion
    }
}
