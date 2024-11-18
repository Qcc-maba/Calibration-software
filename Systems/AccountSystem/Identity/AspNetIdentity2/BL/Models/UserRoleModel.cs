using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class UserRoleModel
    {
        public string RoleName { get; set; }
        public int RoleID { get; set; }

        public UserRoleModel()
        {

        }
        public UserRoleModel(DAL.Role role)
        {
            this.RoleName = role.Name;
            this.RoleID = role.RoleID;
        }
    }
}
