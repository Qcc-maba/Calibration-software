using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class UpdatedUserRoleModel
    {
        public int? RoleGroup { get; set; }
        public int RoleID { get; set; }
        public bool Add { get; set; }
        public bool Remove { get; set; }
    }
}
