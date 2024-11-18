using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager.UnitTest
{
    [TestClass]
    public class ApplicationRoleManager_InMemory : BaseApplicationRoleManager
    {
        #region BaseApplicationRoleManager override

        protected override ApplicationRoleManager CreateManager()
        {
            return RoleManager.ApplicationRoleManager.Create(new RoleStore(new DAL.RoleStoreDAL_InMemory()));
        }

        #endregion
    }
}
