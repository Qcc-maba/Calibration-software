using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager.UnitTest
{
    [TestClass]
    public class ApplicationUserManager_InMemory : BaseApplicationUserManager
    {
        #region ctor(s)

        public ApplicationUserManager_InMemory()
        {

        }

        #endregion

        #region BaseApplicationUserManager override

        protected override ApplicationUserManager OnCreateManager(Settings.IdentitySettings settings)
        {
            return ApplicationUserManager.Create(
                new UserStore.FullUserStore(new UserManager.UserStore.DAL.UserStoreDAL_InMemory()),
                settings);
        }

        protected override RoleManager.ApplicationRoleManager CreateRoleManager()
        {
            return RoleManager.ApplicationRoleManager.Create(new RoleManager.RoleStore(new RoleManager.DAL.RoleStoreDAL_InMemory()));
        }

        #endregion
    }
}
