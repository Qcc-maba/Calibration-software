using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using System.Web.Http;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers
{
    public class BaseController<T> : ApiController where T : DependencyResolves.BaseSettingsCarrier
    {
        #region properties

        public T Carrier { get; internal set; }

        private Identity2.Common.UserData _CurrentUser = null;
        public Identity2.Common.UserData CurrentUser
        {
            get
            {
                if (_CurrentUser != null)
                {
                    return _CurrentUser;
                }

                var identity = GetIdentity();
                var userData = Identity2.Common.AccessTokenHelper.OpenUserTicket(identity);

                _CurrentUser = userData;

                return _CurrentUser;
            }
            internal set
            {
                _CurrentUser = value;
            }
        }

        protected virtual bool ValidateIdentity(ClaimsIdentity identity)
        {
            return true;
        }

        protected ClaimsIdentity GetIdentity(bool ThrowWhenDenied = true, bool InheritedTest = true)
        {
            var identity = this.User.Identity as ClaimsIdentity;

            if (identity == null
                || !identity.IsAuthenticated
                || String.IsNullOrEmpty(identity.AuthenticationType)
                || !identity.AuthenticationType.StartsWith(Identity2.Common.AccessTokenHelper.AUTHENTICATION_TYPE_LOCAL)
                || (InheritedTest && !ValidateIdentity(identity)))
            {
                if (ThrowWhenDenied)
                {
                    throw new HttpResponseException(new HttpResponseMessage(System.Net.HttpStatusCode.Forbidden)
                    {
                        Content = new StringContent("Sorry. No user was found on this session.")
                    });
                }
                else
                {
                    return null;
                }
            }

            return identity;
        }

        protected bool IsSignedIn()
        {
            return GetIdentity(false) != null;
        }

        #endregion
    }
}
