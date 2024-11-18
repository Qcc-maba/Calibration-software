using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager
{
    public class ApplicationUser : IUser
    {
        public ApplicationUser()
        {

        }

        public bool TwoFactorEnabled { get; set; }
        public string SecurityStamp { get; set; }
        public string PhoneNumber { get; set; }
        public bool PhoneConfirmed { get; set; }

        public Boolean AlwaysValid { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }

        public string UserName { get; set; }
        public string PasswordHash { get; set; }

        private long _UserID = -1;
        public long UserID
        {
            get
            { return _UserID; }
            set
            {
                _UserID = value;
                _Id = value.ToString();
            }
        }

        private string _Id = "";
        public string Id
        {
            get
            {
                return _Id;
            }
            set
            {
                _Id = value;
                UserID = long.Parse(value);
            }
        }

        public string UserGuid { get; set; }

        public bool EmailConfirmed { get; set; }

        public int AccessFailedCount { get; set; }

        public bool LockoutEnabled { get; set; }

        public DateTime? LockoutEndDateUtc { get; set; }

        public List<ApplicationUser> Clients { get; set; }

        public async Task<ClaimsIdentity> GenerateUserIdentityAsync(UserManager.ApplicationUserManager manager)
        {
            // Note the authenticationType must match the one defined in CookieAuthenticationOptions.AuthenticationType
            var userIdentity = await manager.CreateIdentityAsync(this, DefaultAuthenticationTypes.ApplicationCookie);
            // Add custom user claims here
            return userIdentity;
        }


    }
}
