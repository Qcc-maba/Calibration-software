using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager.DAL
{
    public interface IRoleStoreDAL : IDisposable
    {
        Role FindById(string Id);
        Role FindByName(string roleName);

        bool Role_Create(Role role);
        bool Role_Delete(Role role);
        bool Role_Update(Role role);
    }
}
