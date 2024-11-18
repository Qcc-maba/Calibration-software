using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class UserClaim
    {
        public long ID { get; set; }
        public long UserId { get; set; }
        public string ClaimType { get; set; }
        public string ClaimValue { get; set; }

        public UserClaim(string type, string value)
        {
            ClaimType = type;
            ClaimValue = value;
        }

        public UserClaim()
        {

        }
    }
}
