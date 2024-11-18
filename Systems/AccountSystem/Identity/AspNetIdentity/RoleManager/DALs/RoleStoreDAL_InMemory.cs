using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager.DAL
{
    public class RoleStoreDAL_InMemory : IRoleStoreDAL
    {
        #region "Table"

        public static long Table_Role__PK_ROLEID = 0;
        public static List<Role> Table_Role { get; set; }

        public static List<UserRole> Table_UserRole { get; set; }

        #endregion

        #region ctor(s)

        static RoleStoreDAL_InMemory()
        {
            Table_Role = new List<Role>();
            Table_UserRole = new List<UserRole>();
        }

        public RoleStoreDAL_InMemory()
        {

        }

        #endregion

        #region IRoleStoreDAL members

        public Role FindById(string Id)
        {
            lock (Table_Role)
            {
                return Table_Role.FirstOrDefault(r => r.Id == Id);
            }
        }

        public Role FindByName(string roleName)
        {
            lock (Table_Role)
            {
                return Table_Role.FirstOrDefault(r => r.Name == roleName);
            }
        }

        public bool Role_Create(Role role)
        {
            lock (Table_Role)
            {
                if (FindByName(role.Name) != null)
                    return false;

                role.Id = (Table_Role__PK_ROLEID++).ToString();
                Table_Role.Add(role);
                return true;
            }
        }

        public bool Role_Delete(Role role)
        {
            lock (Table_Role)
            {
                var _role = Table_Role.FirstOrDefault(r => r.Id == role.Id);
                if (_role != null)
                {
                    return Table_Role.Remove(_role);
                }
                else
                {
                    return false;
                }
            }
        }

        public bool Role_Update(Role role)
        {
            lock (Table_Role)
            {
                var _role = Table_Role.FirstOrDefault(r => r.Id == role.Id);
                if (_role != null)
                {
                    _role.Name = role.Name;
                    return true;
                }
                else
                {
                    return false;
                }
            }
        }

        #endregion

        #region IDisposable members

        public void Dispose()
        {

        }

        #endregion
    }
}
