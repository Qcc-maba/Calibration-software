using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class ValidUserRoleModel : AspNetIdentity.Identity2.BL.Models.UserRoleModel
    {
        public bool Checked { get; set; }
        public bool Enabled { get; set; }
    }
   
}
