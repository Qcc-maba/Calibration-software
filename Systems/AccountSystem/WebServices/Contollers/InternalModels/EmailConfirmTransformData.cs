using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models;

namespace Maba.AccountSystem.WebServices.Contollers.InternalModels
{
    public class EmailConfirmTransformData
    {
        public string Email { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Link { get; set; }
        public ApplicationUserModel UserObject { get; set; }
    }
}
