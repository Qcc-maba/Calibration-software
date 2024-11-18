using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL
{
    public class IdentityConstants
    {
        public const string ROLE_ADMINISTRATOR_PREFIX = "Admin";

        #region ROLES

        //------------------------- General Roles -------------------------
        public const int ROLE_PRINCIPAL__GROUP_ID = 10;
        public const int ROLE_PRINCIPAL__SuperAdmin = 1000;

        //------------------------- Group :: System Roles -------------------------
        public const int ROLE_SYSTEMS__GROUP_ID = 20;
        public const int ROLE_SYSTEMS__MF = 2001;
        public const int ROLE_SYSTEMS__ACCOUNT_ADMIN = 2002;
        public const int ROLE_SYSTEMS__Hydra2_ADMIN = 2003;
        public const int ROLE_SYSTEMS__XCI_ADMIN = 2004;

        #endregion

        #region static methods

        public static bool IsInRole(Models.UserRoleModel[] Roles, int RoleID)
        {
            return Roles != null && Roles.Any(r => r.RoleID == RoleID);
        }

        public static bool IsSuperAdmin(Models.UserRoleModel[] Roles)
        {
            return IsInRole(Roles, ROLE_PRINCIPAL__SuperAdmin);
        }

        #endregion
    }
}
