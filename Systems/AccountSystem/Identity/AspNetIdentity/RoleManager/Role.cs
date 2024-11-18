using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNet.Identity;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager
{
    public class Role : IRole<string>
    {
        #region properties

        public string Id { get; set; }
        public string Name { get; set; }

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
