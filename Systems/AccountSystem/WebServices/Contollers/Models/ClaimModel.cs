using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class ClaimModel
    {
        public string ClaimType { get; set; }
        public string ClaimValue { get; set; }

        public ClaimModel()
        {

        }
        public ClaimModel(AspNetIdentity.Identity2.BL.Models.UserClaimModel c)
        {
            this.ClaimType = c.ClaimType;
            this.ClaimValue = c.ClaimValue;
        }
    }
}
