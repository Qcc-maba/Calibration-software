using Microsoft.AspNet.Identity;
using Microsoft.AspNet.Identity.Owin;
using Microsoft.Owin;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager
{
    public class ApplicationRoleManager : RoleManager<Role>
    {
        #region ctor(s)

        public ApplicationRoleManager(IRoleStore<Role, string> roleStore)
            : base(roleStore)
        {
        }

        #endregion

        #region static methods

        static ApplicationRoleManager()
        {
        }

        public static ApplicationRoleManager Create(IRoleStore<Role, string> store)
        {
            var manager = new ApplicationRoleManager(store);

            return manager;
        }

        public static ApplicationRoleManager Create(IRoleStore<Role, string> store, 
            IdentityFactoryOptions<ApplicationRoleManager> options, IOwinContext context,
            AspNetIdentity.Settings.IdentitySettings settings)
        {
            var manager = new ApplicationRoleManager(store);

            return manager;
        }

        #endregion
    }
}
