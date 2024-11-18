using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories;
using Maba.DAL.BaseDAL;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Test
{
    [TestClass]
    public abstract class BaseAdminTest
    {
        #region members / properties

        protected Repositories.Account.IAccountRepository accountRepository { get; private set; }
        private TesterConnector testConnector = null;

        #endregion

        #region ctor

        public BaseAdminTest()
        {
            accountRepository = new Repositories.Account.TSQL.TSQLAccountRepository();
            testConnector = new TesterConnector(Repositories.Account.TSQL.TSQLAccountRepository.DEFAULT_STRING_CONNECTION);

            OnInit();
        }

        #endregion

        #region abstract methods

        protected abstract void OnInit();

        #endregion

        #region protected methods

        protected long AddUser()
        {
            bool result = false;
            long Max_UserID = 0;
            var r = testConnector.Connector.RunStatement("SELECT MAX(UserID) FROM Account.LoginUser", null, out result);
            if (r.Read() && r.HasRows)
            {
                Max_UserID = r.GetInt64(0);
            }

            var user = new AdminLayer.Models.AccountUser()
            {
                UserID = Max_UserID + 1,
                IdentityUserGUID = Guid.NewGuid().ToString(),
                FirstName = "MyFirstName",
                LastName = "MyLastName",
                CultureCode = "en-US"
            };
            var newUserID = this.accountRepository.AddUser(user);

            return user.UserID;
        }

        #endregion
    }
}
