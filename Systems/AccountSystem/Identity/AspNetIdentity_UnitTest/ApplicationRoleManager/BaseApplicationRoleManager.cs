using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.AccountSystem.AspNetIdentity;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager.UnitTest
{
    public abstract class BaseApplicationRoleManager
    {
        #region members

        private ApplicationRoleManager roleManager = null;

        #endregion

        [TestInitialize]
        public void Init()
        {
            roleManager = CreateManager();
        }

        #region Unit Tests

        [TestMethod]
        public void CreateAsync_Test()
        {
            var role = new Role() { Name = CONSTANTS.ROLE_END_USER2, Id = "44" };
            var task = roleManager.CreateAsync(role);
            task.Wait();
            Assert.IsTrue(task.IsCompleted && task.Result.Succeeded);
        }

        [TestMethod]
        public void DeleteAsync_Test()
        {
            var role = new Role() { Name = "DeleteAsync", Id = "20" };
            var task = roleManager.CreateAsync(role);
            task.Wait();
            Assert.IsTrue(task.IsCompleted && task.Result.Succeeded);

            var task1 = roleManager.DeleteAsync(role);
            task1.Wait();
            Assert.IsTrue(task1.IsCompleted && task1.Result.Succeeded);
        }

        [TestMethod]
        public void FindByIdAsync_Test()
        {
            var role = new Role() { Name = "FindByIdAsync", Id = "21" };
            var task = roleManager.CreateAsync(role);
            task.Wait();
            Assert.IsTrue(task.IsCompleted && task.Result.Succeeded);

            var task1 = roleManager.FindByIdAsync(role.Id);
            task1.Wait();
            Assert.IsTrue(task1.IsCompleted);
            Assert.AreEqual(task1.Result.Name, role.Name);
            Assert.AreEqual(task1.Result.Id, role.Id);

        }

        [TestMethod]
        public void FindByNameAsync_Test()
        {
            var role = new Role() { Name = "FindByNameAsync", Id = "22" };
            var task = roleManager.CreateAsync(role);
            task.Wait();
            Assert.IsTrue(task.IsCompleted && task.Result.Succeeded);

            var task1 = roleManager.FindByNameAsync(role.Name);
            task1.Wait();
            Assert.IsTrue(task1.IsCompleted);
            Assert.AreEqual(task1.Result.Name, role.Name);
            Assert.AreEqual(task1.Result.Id, role.Id);

        }

        [TestMethod]
        public void UpdateAsync_Test()
        {
            var role = new Role() { Name = "UpdateAsync", Id = "22" };
            var task = roleManager.CreateAsync(role);
            task.Wait();
            Assert.IsTrue(task.IsCompleted && task.Result.Succeeded);
            role.Name = "UpdateAsync_222";
            var task1 = roleManager.UpdateAsync(role);
            task1.Wait();
            Assert.IsTrue(task1.IsCompleted && task.Result.Succeeded);


        }

        #endregion

        #region abstract methods

        protected abstract ApplicationRoleManager CreateManager();

        #endregion
    }
}
