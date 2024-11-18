using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager
{
    public class RoleStore : IRoleStore<Role, string>
    {
        #region properties

        public DAL.IRoleStoreDAL Context { get; private set; }

        #endregion

        #region ctor(s)

        public RoleStore(DAL.IRoleStoreDAL context)
        {
            Context = context;
        }

        #endregion

        #region IRoleStore<Role, string>

        public Task CreateAsync(Role role)
        {
            return Task.Factory.StartNew(() => Context.Role_Create(role));
        }

        public Task DeleteAsync(Role role)
        {
            return Task.Factory.StartNew(() => Context.Role_Delete(role));
        }

        public Task<Role> FindByIdAsync(string roleId)
        {
            Task<Role> taskInvoke = Task<Role>.Factory.StartNew(() =>
            {
                return Context.FindById(roleId);
            });

            return taskInvoke;
        }

        public Task<Role> FindByNameAsync(string roleName)
        {
            Task<Role> taskInvoke = Task<Role>.Factory.StartNew(() =>
            {
                return Context.FindByName(roleName);
            });

            return taskInvoke;
        }

        public Task UpdateAsync(Role role)
        {
            return Task.Factory.StartNew(() =>
            {
                return Context.Role_Update(role);
            });
        }

        #endregion

        #region IDisposable

        public void Dispose()
        {
        }

        #endregion
    }
}
