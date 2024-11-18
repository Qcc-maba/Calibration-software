using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class Role
    {
        #region properties

        public int RoleID { get; set; }
        public string Name { get; set; }
        public int RoleGroup { get; set; }

        #endregion

        #region  ctor(s)

        public Role(string rolename)
            : base()
        {
            Name = rolename;
        }

        public Role()
        {

        }

        #endregion
    }
}
