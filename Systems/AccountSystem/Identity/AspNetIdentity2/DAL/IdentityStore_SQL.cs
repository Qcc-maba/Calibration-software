using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2.Settings;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class IdentityStore_SQL : BaseConnector, IIdentityStore
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION_NAME = "Identity2_AdminDBDirect";

        #endregion

        #region ctor(s)

        public IdentityStore_SQL()
            : base(DEFAULT_STRING_CONNECTION_NAME)
        {

        }
        public IdentityStore_SQL(string ConnectionName)
            : base(ConnectionName)
        {

        }

        #endregion

        #region Find user

        public Task<PagedResponse<BaseUserExtendView>> FindUsersAsync(string Search, int PageSize, int PageNumber)
        {
            return Task.Run(() =>
            {
                var totalItemsOutParameter = Connector.CreateOutParameter("TotalItems", (long)0);

                var items = Connector.GetEntities<BaseUserExtendView>(Connector.CreateProcedureEnumerator("UserManager.UsersSearch_Paged",
                                                 new IDataParameter[]
                                                 {
                                                     Connector.CreateParameter("Search", Search),
                                                     Connector.CreateParameter("PageSize", PageSize),
                                                     Connector.CreateParameter("PageNumber", PageNumber),
                                                     totalItemsOutParameter
                                                 }));

                return new PagedResponse<BaseUserExtendView>()
                {
                    Items = items.ToArray(),
                    RequestedPageNumber = PageNumber,
                    RequestedPageSize = PageSize,
                    TotalItems = totalItemsOutParameter.Value == DBNull.Value
                                    ? (long)0
                                    : (long)totalItemsOutParameter.Value
                };
            });
        }

        public Task<bool> User_UpdateSecurityStampAsync(long UserID, string SecurityStamp)
        {
            return Task.Run(() =>
            {
                bool Result = false;
                int affected = 0;
                Connector.GetProcedureResultInt64("UserManager.User_UpdateSecurityStamp",
                          new IDataParameter[] {
                           Connector.CreateParameter("UserID",UserID),
                           Connector.CreateParameter("SecurityStamp",SecurityStamp),

                   }, out affected, out Result);
                return Result;
            });
        }

        public Task<BaseUserExtendView> FindByIdAsync(long UserId)
        {
            return Task.Run(() =>
                {
                    return Connector.GetEntity<BaseUserExtendView>(Connector.CreateProcedureEnumerator("UserManager.User_FindById",
                                                             new IDataParameter[] { Connector.CreateParameter("UserID", UserId) }));
                });
        }

        public Task<BaseUserExtendView> FindByUserNameAsync(string UserName)
        {
            return Task.Run(() =>
                {
                    return Connector.GetEntity<BaseUserExtendView>(Connector.CreateProcedureEnumerator("UserManager.User_FindByName",
                                                     new IDataParameter[] { Connector.CreateParameter("UserName", UserName) }));
                });
        }

        public Task<BaseUserExtendView> FindByEmailAsync(string email)
        {

            return Task.Run(() =>
                {
                    return Connector.GetEntity<BaseUserExtendView>(Connector.CreateProcedureEnumerator("UserManager.User_GetUserByEmail",
                                                  new IDataParameter[] { Connector.CreateParameter("Email", email) }));
                });
        }

        #endregion

        #region User - Create, Delete & Update

        public async Task<bool> User_CreateAsync(BaseUser user, bool UseDefaultTypes)
        {
            bool Result = false;
            int rowAffected = 0;

            await Task.Run(() =>
               {
                   user.UserID = Connector.GetProcedureResultInt64("UserManager.User_Create",
                             new IDataParameter[] {
                                            Connector.CreateParameter("UseDefaultTypes", UseDefaultTypes),

                                            Connector.CreateParameter("UserGuid", user.UserGuid),
                                            Connector.CreateParameter("UserName", user.UserName),
                                            Connector.CreateParameter("Version", user.UpdateVersion),

                                            Connector.CreateParameter("City",user.City),
                                            Connector.CreateParameter("Country",user.Country),
                                            Connector.CreateParameter("FirstName", user.FirstName),
                                            Connector.CreateParameter("LastName", user.LastName),
                                            Connector.CreateParameter("ZipCode",user.ZipCode),
                                            Connector.CreateParameter("StreetName",user.StreetName),
                                            Connector.CreateParameter("StreetNo",user.StreetNo),

                                            Connector.CreateParameter("Email", user.Email),
                                            Connector.CreateParameter("EmailConfirmed", user.EmailConfirmed),
                                            Connector.CreateParameter("PhoneNumber", user.PhoneNumber),
                                            Connector.CreateParameter("PhoneConfirmed", user.PhoneConfirmed),

                                            Connector.CreateParameter("UIFormatID", user.UIFormatID),
                                            Connector.CreateParameter("CustomLongDatePattern", user.LongDatePattern),
                                            Connector.CreateParameter("CustomLongTimePattern", user.LongTimePattern),
                                            Connector.CreateParameter("CustomShortTimePattern", user.ShortTimePattern),
                                            Connector.CreateParameter("CustomShortDatePattern", user.ShortDatePattern),

                                            Connector.CreateParameter("PasswordHash",user.PasswordHash),
                                            Connector.CreateParameter("SecurityStamp",user.SecurityStamp),

                                            Connector.CreateParameter("TimeZoneID",user.TimeZoneID),
                                            Connector.CreateParameter("TemperatureUnitID",user.TemperatureUnitID),


                             }, out rowAffected, out Result);
               });

            if (!Result)
            {
                user.UserID = -1;
            }

            return Result;
        }

        public Task<bool> User_DeleteByEmailAsync(string Email)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;
                    Connector.GetProcedureResultInt64("UserManager.User_DeleteByEmail",
                              new IDataParameter[] {
                           Connector.CreateParameter("Email",Email),
                       }, out affected,
                                  out Result);
                    return Result;
                });
        }

        public Task<bool> User_DeleteByIdAsync(long UserId)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;

                    Connector.GetProcedureResultInt64("UserManager.User_DeleteById",
                              new IDataParameter[] {
                           Connector.CreateParameter("Id",UserId),
                       }, out affected, out Result);
                    return Result;
                });
        }

        public Task<bool> User_UpdateAsync(BaseUser user, bool UpdateVersion = false)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;
                    Connector.GetProcedureResultInt64("UserManager.User_Update",
                              new IDataParameter[] {
                                                    Connector.CreateParameter("UserID", user.UserID),

                                                    Connector.CreateParameter("LockoutEnabled",user.LockoutEnabled),
                                                    Connector.CreateParameter("LockoutEndDateUtc",user.LockoutEndDateUtc),
                                                    Connector.CreateParameter("AccessFailedCount",user.AccessFailedCount),

                                                    Connector.CreateParameter("LastFailedLoginDateUtc",user.LastFailedLoginDateUtc),
                                                    Connector.CreateParameter("LastLoginDateUtc",user.LastLoginDateUtc),

                                                    Connector.CreateParameter("UserName",user.UserName),
                                                    Connector.CreateParameter("Version",UpdateVersion ? user.UpdateVersion : (int?)null),

                                                    Connector.CreateParameter("City",user.City),
                                                    Connector.CreateParameter("Country",user.Country),
                                                    Connector.CreateParameter("FirstName", user.FirstName),
                                                    Connector.CreateParameter("LastName", user.LastName),
                                                    Connector.CreateParameter("ZipCode",user.ZipCode),
                                                    Connector.CreateParameter("StreetName",user.StreetName),
                                                    Connector.CreateParameter("StreetNo",user.StreetNo),

                                                    Connector.CreateParameter("Email", user.Email),
                                                    Connector.CreateParameter("EmailConfirmed", user.EmailConfirmed),
                                                    Connector.CreateParameter("PhoneNumber", user.PhoneNumber),
                                                    Connector.CreateParameter("PhoneConfirmed", user.PhoneConfirmed),

                                                    Connector.CreateParameter("UIFormatID", user.UIFormatID),
                                                    Connector.CreateParameter("CustomLongDatePattern", user.LongDatePattern),
                                                    Connector.CreateParameter("CustomLongTimePattern", user.LongTimePattern),
                                                    Connector.CreateParameter("CustomShortTimePattern", user.ShortTimePattern),
                                                    Connector.CreateParameter("CustomShortDatePattern", user.ShortDatePattern),

                                                    Connector.CreateParameter("PasswordHash",user.PasswordHash),
                                                    Connector.CreateParameter("SecurityStamp",user.SecurityStamp),

                                                    Connector.CreateParameter("TimeZoneID",user.TimeZoneID),
                                                    Connector.CreateParameter("TemperatureUnitID",user.TemperatureUnitID),
                                                    },
                                  out affected, out Result);
                    return Result;
                });
        }

        public Task<bool> User_UpdatePhoneNumberChangeTokenAsync(long UserID, string VerificationCode)
        {
            return Task.Run(() =>
            {
                bool Result = false;
                int affected = 0;
                Connector.GetProcedureResultInt64("UserManager.User_UpdatePhoneNumberChangeToken",
                          new IDataParameter[] {
                            Connector.CreateParameter("UserID", UserID),
                            Connector.CreateParameter("Token", VerificationCode),
                       }, out affected, out Result);
                return Result;
            });
        }

        public Task<PhoneVerificationCode> User_GetPhoneNumberChangeTokenAsync(long UserID)
        {
            return Task.Run(() =>
            {
                return Connector
                    .GetEntity<PhoneVerificationCode>(Connector.CreateProcedureEnumerator("UserManager.User_GetPhoneNumberChangeToken",
                                                            new IDataParameter[] {
                                                                Connector.CreateParameter("UserID", UserID)
                                                            }));
            });
        }

        #endregion

        #region User's Claims

        public Task<bool> User_AddClaimAsync(long UserID, UserClaim claim)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;

                    Connector.GetProcedureResultInt64("UserManager.User_AddClaim",
                               new IDataParameter[] {
                           Connector.CreateParameter("Value", claim.ClaimValue),
                           Connector.CreateParameter("Type", claim.ClaimType),
                           Connector.CreateParameter("UserID",UserID)
                        }, out affected, out Result);

                    if (Result)
                    {
                        claim.UserId = UserID;
                    }
                    return Result;
                });
        }

        public Task<IEnumerable<UserClaim>> User_GetClaimsAsync(long UserId)
        {
            return Task.Run(() =>
                {
                    return Connector.GetEntities<UserClaim>(Connector.CreateProcedureEnumerator("UserManager.User_GetClaims",
                                                           new IDataParameter[] { Connector.CreateParameter("UserId", UserId) }));
                });
        }

        public Task<bool> User_RemoveClaimAsync(long UserID, string ClaimType)
        {
            return Task.Run(() =>
                   {
                       bool Result = false;
                       int affected = 0;

                       Connector.GetProcedureResultInt64("UserManager.User_RemoveClaim",
                                 new IDataParameter[] {
                           Connector.CreateParameter("Type", ClaimType),
                           Connector.CreateParameter("UserID", UserID)
                       }, out affected, out Result);

                       return Result;
                   });
        }

        #endregion

        #region Managing Roles

        public Task<Role> Role_FindByIdAsync(int RoleId)
        {
            return Task.Run(() =>
                      {
                          return Connector
                              .GetEntity<Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_FindById",
                                                                      new IDataParameter[] { Connector.CreateParameter("Id", RoleId) }));
                      });
        }

        public Task<Role> Role_FindByNameAsync(string RoleName)
        {
            return Task.Run(() =>
                   {
                       return Connector
                           .GetEntity<Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_FindByName",
                                                                new IDataParameter[] { Connector.CreateParameter("@Name", RoleName) }));
                   });

        }
        public Task<Role[]> System_Role_GetAll(int? FilterGroup)
        {
            return Task.Run(() =>
            {
                return Connector
                    .GetEntities<Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_GetAll",
                                                         new IDataParameter[]
                                                         {
                                                             this.Connector.CreateParameter("FilterGroup", FilterGroup)
                                                         }))
                                                         .ToArray();
            });

        }

        public Task<bool> Role_CreateAsync(Role role)
        {
            return Task.Run(() =>
                   {
                       bool Result = false;
                       int affected = 0;
                       Connector.GetProcedureResultInt64("RoleManager.Role_Create",
                                 new IDataParameter[] {
                            Connector.CreateParameter("Name", role.Name),
                            Connector.CreateParameter("Id", role.RoleID),
                            Connector.CreateParameter("RoleGroup", role.RoleGroup)
                       }, out affected, out Result);
                       return Result;
                   });
        }

        public Task<bool> Role_DeleteByIdAsync(int RoleId)
        {
            return Task.Run(() =>
                   {
                       bool Result = false;
                       int affected = 0;

                       Connector.GetProcedureResultInt64("RoleManager.Role_DeleteById",
                                 new IDataParameter[] {
                           Connector.CreateParameter("@Id", RoleId)
                       }, out affected, out Result);
                       return Result;
                   });
        }

        public Task<bool> Role_DeleteByNameAsync(string RoleName)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;
                    Connector.GetProcedureResultInt64("RoleManager.Role_DeleteByName",
                              new IDataParameter[] {
                           Connector.CreateParameter("@Name", RoleName)
                       }, out affected,
                                  out Result);
                    return Result;
                });
        }

        public Task<bool> Role_UpdateAsync(Role role)
        {
            return Task.Run(() =>
            {
                bool Result = false;
                int affectedRow = 0;
                Connector.GetProcedureResultInt64("RoleManager.Role_Update",
                          new IDataParameter[] {
                           Connector.CreateParameter("@Id", role.RoleID),
                           Connector.CreateParameter("@Name", role.Name),
                           Connector.CreateParameter("RoleGroup", role.RoleGroup)
                       }, out affectedRow,
                              out Result);
                return Result;
            });
        }

        #endregion

        #region User's Roles

        public Task<bool> UserInsertRoleAsync(long UserId, int RoleID)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;

                    Connector.GetProcedureResultInt64("RoleManager.Role_UserInsertRole",
                              new IDataParameter[] {
                            Connector.CreateParameter("UserID", UserId ),
                            Connector.CreateParameter("RoleID", RoleID)
                       }, out affected, out Result);
                    return Result;
                });
        }

        public Task<bool> IsUserHasRoleAsync(long UserId, int roleID)
        {
            return Task.Run(() =>
                   {
                       bool Result = false;
                       int rowAffected = 0;
                       var queryResult = Connector.GetProcedureResultInt32("RoleManager.IsUserHasRole",
                                 new IDataParameter[] {
                                                    Connector.CreateParameter("UserID", UserId),
                                                    Connector.CreateParameter("RoleID", roleID)
                       },
                       out rowAffected, out Result);

                       return Result && queryResult == 1;
                   });
        }

        public Task<Role[]> GetUserRolesAsync(long UserID, int? FilterGroup)
        {
            return Task.Run(() =>
                {
                    return Connector.GetEntities<Role>(Connector.CreateProcedureEnumerator("RoleManager.Role_GetUserRoles",
                                                  new IDataParameter[]
                                                  {
                                                      Connector.CreateParameter("UserID", UserID),
                                                      Connector.CreateParameter("FilterGroup", FilterGroup)
                                                  }))
                                                 .ToArray();
                });
        }

        public Task<bool> RemoveUserRoleAsync(long UserID, int RoleID)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;

                    Connector.GetProcedureResultInt64("RoleManager.Role_RemoveUserRole",
                               new IDataParameter[] {
                            Connector.CreateParameter("UserID", UserID),
                            Connector.CreateParameter("RoleID", RoleID)
                        }, out affected, out Result);
                    return Result;
                });
        }

        #endregion

        #region Manage User's logins

        public Task<bool> AddUserLoginAsync(long UserID, UserLoginInfo login)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;

                    Connector.GetProcedureResultInt64("UserManager.User_AddUserLogin",
                              new IDataParameter[] {
                                            Connector.CreateParameter("UserId", UserID),
                                            Connector.CreateParameter("LoginProvider", login.LoginProvider),
                                            Connector.CreateParameter("ProviderKey", login.ProviderKey)
                                   }, out affected, out Result);


                    return Result;
                });
        }

        public Task<bool> User_UpdateImageAsync(long UserID, string ImageURI)
        {
            return Task.Run(() =>
            {
                bool Result = false;
                int affected = 0;
                Connector.GetProcedureResultInt64("UserManager.User_UpdateImage",
                          new IDataParameter[] {
                                            Connector.CreateParameter("UserID", UserID),
                                            Connector.CreateParameter("ImageURI", ImageURI)
                                             },
                              out affected, out Result);


                return Result;
            });
        }

        public Task<bool> RemoveUserLoginAsync(long UserID, UserLoginInfo login)
        {
            return Task.Run(() =>
                {
                    bool Result = false;
                    int affected = 0;
                    Connector.GetProcedureResultInt64("UserManager.User_RemoveUserLogin",
                               new IDataParameter[] {
                                    Connector.CreateParameter("UserId", UserID),
                                    Connector.CreateParameter("LoginProvider", login.LoginProvider),
                                    Connector.CreateParameter("ProviderKey", login.ProviderKey)
                            }, out affected, out Result);
                    return Result;
                });
        }

        public Task<IEnumerable<UserLoginInfo>> GetUserLoginsAsync(long UserID)
        {
            return Task.Run(() =>
                {
                    return Connector.GetEntities<UserLoginInfo>(Connector.CreateProcedureEnumerator("UserManager.User_GetUserLogins",
                                                            new IDataParameter[] { Connector.CreateParameter("UserID", UserID) }));
                });
        }

        public Task<BaseUserExtendView> FindByLoginUserAsync(UserLoginInfo login)
        {
            return Task.Run(() =>
                {
                    return Connector.GetEntity<BaseUserExtendView>(Connector.CreateProcedureEnumerator("UserManager.User_FindByLoginUser",
                                                             new IDataParameter[]
                                                             {
                                                                 Connector.CreateParameter("LoginProvider", login.LoginProvider),
                                                                 Connector.CreateParameter("ProviderKey", login.ProviderKey)
                                                             }));
                });
        }

        #endregion

        #region System
        public Task<SystemTimeZone[]> GetSystemTimeZonesAsync()
        {
            return Task.Run(() =>
            {
                return Connector.GetEntities<SystemTimeZone>(Connector.CreateProcedureEnumerator("Types.GetSystemTimeZone",
                                                   null))
                                                   .ToArray();
            });
        }

        public Task<SystemUIFormat[]> GetUIFormatsAsync()
        {
            return Task.Run(() =>
            {
                return Connector.GetEntities<SystemUIFormat>(Connector.CreateProcedureEnumerator("Types.GetSystemCultureCode",
                                                   null))
                                                   .ToArray();
            });

        }

        public Task<SystemTemperatureUnit[]> GetSystemTemperatureUnitsAsync()
        {
            return Task.Run(() =>
            {
                return Connector.GetEntities<SystemTemperatureUnit>(Connector.CreateProcedureEnumerator("Types.GetSystemTemperatureUnit",
                                                   null))
                                                   .ToArray();
            });
        }
        #endregion
    }
}
