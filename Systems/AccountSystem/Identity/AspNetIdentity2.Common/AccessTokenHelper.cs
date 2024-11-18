using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNet.Identity;
using Microsoft.Owin.Security;
using Microsoft.Owin.Security.DataHandler;
using Microsoft.Owin.Security.DataProtection;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Common
{
    public class AccessTokenHelper
    {
        #region CONSTANTS

        public const string AUTHENTICATION_TYPE_LOCAL = "Maba";

        #endregion

        #region properties

        public TicketDataFormat TicketDataProtector { get; private set; }

        #endregion

        #region ctor

        private AccessTokenHelper(IDataProtector dataProtector)
        {
            TicketDataProtector = new Microsoft.Owin.Security.DataHandler.TicketDataFormat(dataProtector);
        }

        #endregion

        #region methods


        public string Protect(AuthenticationTicket ticket)
        {
            return this.TicketDataProtector.Protect(ticket);
        }

        public AuthenticationTicket Unprotect(string protectedTicket)
        {
            return this.TicketDataProtector.Unprotect(protectedTicket);
        }

        #endregion

        #region static methods

        public static UserData OpenUserTicket(ClaimsIdentity Identity)
        {
            var d = new UserData()
            {
                UserName = Identity.GetUserName(),
                UserID = Identity.GetUserId(),
                UserGUID = Identity.GetUserGUID(),
                LoginProvider = Identity.AuthenticationType,
                Email = Identity.GetEmail(),
                Surename = Identity.GetClaimValue(ClaimTypes.Surname),
                GivenName = Identity.GetClaimValue(ClaimTypes.GivenName)
            };

            return d;
        }

        public static AuthenticationTicket CreateUserTicket(UserData user, Claim[] Claims, bool AddExtra = false)
        {
            var userIdentity = new ClaimsIdentity(user.LoginProvider);

            if (AddExtra)
            {
                userIdentity.AddClaim(new Claim(ClaimTypes.Name, user.UserName));

                if (!String.IsNullOrEmpty(user.Surename))
                {
                    userIdentity.AddClaim(new Claim(ClaimTypes.Surname, user.Surename));
                }

                userIdentity.SetUserGUID(user.UserGUID);
            }

            if (!String.IsNullOrEmpty(user.GivenName))
            {
                userIdentity.AddClaim(new Claim(ClaimTypes.GivenName, user.GivenName));
            }
            userIdentity.AddClaim(new Claim(ClaimTypes.Sid, user.UserID.ToString()));
            userIdentity.AddClaim(new Claim(ClaimTypes.Email, user.Email));

            if (Claims != null && Claims.Length > 0)
            {
                userIdentity.AddClaims(Claims);
            }

            var ticket = CreateUserTicket(userIdentity);
            return ticket;
        }

        public static AuthenticationTicket CreateUserTicket(ClaimsIdentity identity)
        {
            var properties = new AuthenticationProperties()
            {
                IssuedUtc = DateTime.UtcNow,
                ExpiresUtc = DateTime.UtcNow.AddDays(7)
            };

            var ticket = new AuthenticationTicket(identity, properties);

            return ticket;
        }


        public static AccessTokenHelper CreateAccessTokenHelper(IDataProtectionProvider dataProtectionProvider, params string[] purposes)
        {
            var TokenHelper = new AccessTokenHelper(dataProtectionProvider.Create(purposes));

            return TokenHelper;
        }

        #endregion
    }
}
