using Maba.DAL.BaseDAL;
using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.RoleManager.DAL
{
    public class RoleStoreDAL_DBConnector : BaseConnector, IRoleStoreDAL
    {
        #region constants

        public const string DEFAULT_STRING_CONNECTION_NAME = "CRI_AdminDBDirect";

        #endregion

        #region ctor(s)

        public RoleStoreDAL_DBConnector()
            : base(DEFAULT_STRING_CONNECTION_NAME)
        {

        }
        public RoleStoreDAL_DBConnector(string ConnectionName)
            : base(ConnectionName)
        {

        }

        #endregion

        #region IRoleStoreDAL members

        public Role FindById(string Id)
        {
            int RoleID = -1;
            int.TryParse(Id, out RoleID);
            return Connector
                .GetEntities<Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_FindById",
                                                        new IDataParameter[] { Connector.CreateParameter("Id", RoleID) }))
                 .FirstOrDefault();
        }

        public Role FindByName(string RoleName)
        {
            return Connector
                .GetEntities<Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_FindByName",
                                                     new IDataParameter[] { Connector.CreateParameter("@Name", RoleName) }))
               .FirstOrDefault();

        }

        public bool Role_Create(Role role)
        {
            bool Result = false;
            int RoleID = -1;
            int.TryParse(role.Id, out RoleID);
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_Create",
                      new IDataParameter[] { 
                            Connector.CreateParameter("@Name", role.Name), 
                            Connector.CreateParameter("@Id", RoleID)
                       },
                          out Result), null);
            return Result;
        }

        public bool Role_Delete(Role role)
        {
            int RoleID = -1;
            int.TryParse(role.Id, out RoleID);
            bool Result = false;
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_Delete",
                      new IDataParameter[] { 
                           Connector.CreateParameter("@Id", RoleID)
                       },
                          out Result), null);
            return Result;
        }

        public bool Role_Update(Role role)
        {
            int RoleID = -1;
            int.TryParse(role.Id, out RoleID);
            bool Result = false;
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_Update",
                      new IDataParameter[] { 
                           Connector.CreateParameter("@Id", RoleID), 
                           Connector.CreateParameter("@Name", role.Name)
                       },
                          out Result), null);
            return Result;
        }

        #endregion
    }
}
