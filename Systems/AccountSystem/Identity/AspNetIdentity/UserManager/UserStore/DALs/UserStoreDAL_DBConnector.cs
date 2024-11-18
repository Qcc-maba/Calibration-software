using Maba.DAL.BaseDAL;
using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager.UserStore.DAL
{
    public class UserStoreDAL_DBConnector : BaseConnector, IUserStoreDAL
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION_NAME = "CRI_AdminDBDirect";

        #endregion

        #region ctor(s)

        public UserStoreDAL_DBConnector()
            : base(DEFAULT_STRING_CONNECTION_NAME)
        {

        }
        public UserStoreDAL_DBConnector(string ConnectionName)
            : base(ConnectionName)
        {

        }

        #endregion

        #region IUserStoreDAL

        #region IUserStore

        public IEnumerable<ApplicationUser> FindById(string Id)
        {
            long userID = -1;
            long.TryParse(Id, out userID);
            return Connector.GetEntities<ApplicationUser>(Connector.CreateProcedureEnumerator("UserManager.User_FindById",
                                                     new IDataParameter[] { Connector.CreateParameter("Id", userID) }));
        }

        public IEnumerable<ApplicationUser> FindByName(string UserName)
        {

            return Connector.GetEntities<ApplicationUser>(Connector.CreateProcedureEnumerator("UserManager.User_FindByName",
                                                     new IDataParameter[] { Connector.CreateParameter("UserName", UserName) }));
        }

        public bool User_Create(ApplicationUser user)
        {
            user.UserGuid = Guid.NewGuid().ToString();

            bool Result = false;
            user.UserID = -1;
            var p = Connector.CreateOutParameter("Id", user.UserID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_Create",
                      new IDataParameter[] { 
                            Connector.CreateParameter("UserName", user.UserName), 
                            Connector.CreateParameter("FirstName", user.FirstName), 
                            Connector.CreateParameter("LastName", user.LastName), 
                            Connector.CreateParameter("UserGuid", user.UserGuid), 
                            Connector.CreateParameter("PasswordHash",user.PasswordHash),
                            Connector.CreateParameter("Email",user.Email),
                            Connector.CreateParameter("PhoneNumber", user.PhoneNumber), 
                            Connector.CreateParameter("PhoneConfirmed", user.PhoneConfirmed), 
                            Connector.CreateParameter("EmailConfirmed", user.EmailConfirmed), 
                            Connector.CreateParameter("LockoutEndDateUtc",user.LockoutEndDateUtc),
                            Connector.CreateParameter("LockoutEnabled",user.LockoutEnabled),
                            Connector.CreateParameter("SecurityStamp",user.SecurityStamp),
                            Connector.CreateParameter("TwoFactorEnabled",user.TwoFactorEnabled),
                           p
                       },
                          out Result), null);

            if (Result)
            {
                user.UserID = (long)p.Value;
            }
            else
            {
                user.UserID = -1;
            }

            return Result;
        }

        public bool User_Delete(ApplicationUser user)
        {
            bool Result = false;
            long userID = -1;
            long.TryParse(user.Id, out userID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_Delete",
                      new IDataParameter[] { 
                           Connector.CreateParameter("Id",userID), 
                       },
                          out Result), null);
            return Result;

        }

        public bool User_Update(ApplicationUser user)
        {
            bool Result = false;
            //long userID = -1;
            // long.TryParse(user.Id, out userID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_Update",
                      new IDataParameter[] { 
                            Connector.CreateParameter("FirstName", user.FirstName), 
                            Connector.CreateParameter("PhoneNumber", user.PhoneNumber), 
                            Connector.CreateParameter("PhoneConfirmed", user.PhoneConfirmed), 
                            Connector.CreateParameter("EmailConfirmed", user.EmailConfirmed), 
                            Connector.CreateParameter("Email", user.Email), 
                            Connector.CreateParameter("LastName", user.LastName), 
                            Connector.CreateParameter("UserGuid", user.UserGuid), 
                            Connector.CreateParameter("Id", user.UserID), 
                            Connector.CreateParameter("UserName", user.UserName), 
                            Connector.CreateParameter("PasswordHash",user.PasswordHash),
                            Connector.CreateParameter("AccessFailedCount",user.AccessFailedCount),
                            Connector.CreateParameter("LockoutEndDateUtc",user.LockoutEndDateUtc),
                            Connector.CreateParameter("LockoutEnabled",user.LockoutEnabled),
                            Connector.CreateParameter("SecurityStamp",user.SecurityStamp),
                            Connector.CreateParameter("TwoFactorEnabled",user.TwoFactorEnabled)
                           },
                          out Result), null);
            return Result;

        }

        #endregion

        #region IUserLoginStore

        public bool AddUserLogin(ApplicationUser user, UserLoginInfo login)
        {
            bool Result = false;
            long userID = -1;
            long.TryParse(user.Id, out userID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_AddUserLogin",
                      new IDataParameter[] { 
                                    Connector.CreateParameter("Id", userID), 
                                    Connector.CreateParameter("LoginProvider", login.LoginProvider),
                                    Connector.CreateParameter("ProviderKey", login.ProviderKey)
                           },
                          out Result), null);
            return Result;
        }


        public bool RemoveUserLogin(ApplicationUser user, UserLoginInfo login)
        {
            bool Result = false;
            long userID = -1;
            long.TryParse(user.Id, out userID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_RemoveUserLogin",
                      new IDataParameter[] { 
                                    Connector.CreateParameter("Id", userID), 
                                    Connector.CreateParameter("LoginProvider", login.LoginProvider),
                                    Connector.CreateParameter("ProviderKey", login.ProviderKey)
                           },
                          out Result), null);
            return Result;
        }

        public IEnumerable<UserLoginInfo> GetUserLogins(ApplicationUser user)
        {
            long userID = -1;
            long.TryParse(user.Id, out userID);
            var list = Connector.GetEntities<UserLogin>(Connector.CreateProcedureEnumerator("UserManager.User_GetUserLogins",
                                                            new IDataParameter[] { Connector.CreateParameter("Id", userID) })).ToList();
            if (list != null && list.Count > 0)
            {
                foreach (var item in list)
                {
                    yield return new UserLoginInfo(item.LoginProvider, item.ProviderKey);
                }
            }

            else
                yield break;
        }

        public ApplicationUser FindByLoginUser(UserLoginInfo login)
        {
            var list = Connector.GetEntities<ApplicationUser>(Connector.CreateProcedureEnumerator("UserManager.User_FindByLoginUser",
                                                     new IDataParameter[] { Connector.CreateParameter("LoginProvider", login.LoginProvider),
                                                                            Connector.CreateParameter("ProviderKey", login.ProviderKey)})).ToList();
            if (list != null && list.Count > 0)
            {
                return list[0];
            }
            else
                return null;

        }

        #endregion

        #region IUserRoleStore

        public string GetRoleId(string roleName)
        {
            bool Result = false;
            string RoleId = "";
            var p = Connector.CreateOutParameter("RoleId", RoleId);
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_GetRoleId",
                      new IDataParameter[] { p, Connector.CreateParameter("RoleName", roleName) },
                          out Result), null);

            RoleId = p.Value != null ? p.Value.ToString() : null;
            return RoleId; ;
        }

        public bool InsertRole(ApplicationUser user, string roleName)
        {
            bool Result = false;
            long UserID = -1;
            long.TryParse(user.Id, out UserID);
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_UserInsertRole",
                      new IDataParameter[] { 
                            Connector.CreateParameter("UserID", UserID ), 
                            Connector.CreateParameter("RoleName", roleName), 
                       },
                          out Result), null);
            return Result;
        }



        public IEnumerable<RoleManager.Role> GetUserRoles(string Id)
        {
            long UserID = -1;
            long.TryParse(Id, out UserID);
            return Connector.GetEntities<RoleManager.Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_GetUserRoles",
                                                 new IDataParameter[] { Connector.CreateParameter("UserID", UserID) }));

        }


        public bool IsInRole(string Id, string roleName)
        {
            bool Result = false;
            Int16 value = -1;
            long UserID = -1;
            long.TryParse(Id, out UserID);
            var p = Connector.CreateOutParameter("Result", value);
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_UserIsInRole",
                      new IDataParameter[] { 
                            Connector.CreateParameter("UserID", UserID), 
                            Connector.CreateParameter("RoleName", roleName), 
                            p
                       },
                          out Result), null);

            Result = ((Int16)p.Value == 1);

            return Result;
        }


        public bool RemoveRole(ApplicationUser user, string roleName)
        {
            bool Result = false;
            long UserID = -1;
            long.TryParse(user.Id, out UserID);
            var p = Connector.CreateOutParameter("Result", Result);
            Connector.WrapDataReader(Connector.RunProcedure("RoleManager.Role_RemoveRole",
                      new IDataParameter[] { 
                            Connector.CreateParameter("UserID", UserID), 
                            Connector.CreateParameter("RoleName", roleName), p
                       },
                          out Result), null);
            return Result;
        }

        #endregion

        #region IUserEmailStore

        public IEnumerable<ApplicationUser> GetUserByEmail(string email)
        {
            return Connector.GetEntities<ApplicationUser>(Connector.CreateProcedureEnumerator("UserManager.User_GetUserByEmail",
                                                  new IDataParameter[] { Connector.CreateParameter("Email", email) })).ToList();
        }

        #endregion

        #region  IUserClaimStore

        public bool User_AddClaim(ApplicationUser user, Claim claim)
        {
            bool Result = false;
            long UserID = -1;
            long.TryParse(user.Id, out UserID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_AddClaim",
                      new IDataParameter[] { 
                           Connector.CreateParameter("Value", claim.Value), 
                           Connector.CreateParameter("Type", claim.Type), 
                           Connector.CreateParameter("Id",UserID)
                       },
                          out Result), null);
            return Result;
        }

        public IList<Claim> User_GetClaims(string Id)
        {
            long UserID = -1;
            long.TryParse(Id, out UserID);
            return Connector.GetEntities<UserClaim>(Connector.CreateProcedureEnumerator("UserManager.User_GetClaims",
                                                   new IDataParameter[] { Connector.CreateParameter("Id", UserID) }))
                                                   .Select(c => new Claim(c.ClaimType, c.ClaimValue))
                                                   .ToList();

        }

        public bool User_RemoveClaim(ApplicationUser user, Claim claim)
        {
            bool Result = false;
            long UserID = -1;
            long.TryParse(user.Id, out UserID);
            Connector.WrapDataReader(Connector.RunProcedure("UserManager.User_RemoveClaim",
                      new IDataParameter[] { 
                           Connector.CreateParameter("Value", claim.Value), 
                           Connector.CreateParameter("Type", claim.Type), 
                           Connector.CreateParameter("Id", UserID)
                       },
                          out Result), null);
            return Result;
        }
        #endregion

        #endregion
    }
}
