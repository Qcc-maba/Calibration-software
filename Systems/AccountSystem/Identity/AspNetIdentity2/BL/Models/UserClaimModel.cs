using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class UserClaimModel
    {
        public long ID { get; set; }
        public long UserID { get; set; }
        public string ClaimType { get; set; }
        public string ClaimValue { get; set; }

        public UserClaimModel()
        {

        }


        public UserClaimModel(string type, string value)
        {
            this.ClaimType = type;
            this.ClaimValue = value;
        }

        public UserClaimModel(DAL.UserClaim c)
        {
            this.ID = c.ID;
            this.UserID = c.UserId;
            this.ClaimType = c.ClaimType;
            this.ClaimValue = c.ClaimValue;
        }

        public DAL.UserClaim ToDAL()
        {
            return new DAL.UserClaim()
            {
                ClaimType = this.ClaimType,
                ClaimValue = this.ClaimValue,
                ID = this.ID,
                UserId = this.UserID
            };
        }
    }
}
