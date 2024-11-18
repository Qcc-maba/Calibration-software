using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class ApplicationDetailedUserModel
    {
        public Models.ClaimModel[] Claims { get; set; }
        public AspNetIdentity.Identity2.BL.Models.ApplicationUserModel UserProfile { get; set; }

        public ApplicationDetailedUserModel()
        {

        }
    }
}
