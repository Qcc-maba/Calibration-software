using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class UserLoginInfoModel
    {
        #region properties

        public string LoginProvider { get; set; }
        public string ProviderKey { get; set; }

        #endregion

        public UserLoginInfoModel()
        {

        }

        public UserLoginInfoModel(string provider, string key)
        {
            this.LoginProvider = provider;
            this.ProviderKey = key;
        }

        public UserLoginInfoModel(DAL.UserLoginInfo u)
        {
            this.LoginProvider = u.LoginProvider;
            this.ProviderKey = u.ProviderKey;
        }

        internal DAL.UserLoginInfo ToDAL()
        {
            return new DAL.UserLoginInfo()
            {
                LoginProvider = this.LoginProvider,
                ProviderKey = this.ProviderKey
            };
        }
    }
}
