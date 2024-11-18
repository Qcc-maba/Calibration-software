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
    public class UserStoreDAL_InMemory : IUserStoreDAL
    {
        #region "Tables"

        public static long Table_User__PK_USERID = 0;
        public static List<ApplicationUser> Table_User { get; set; }

        public static List<UserLogin> Table_UserLogin { get; set; }

        public static List<RoleManager.UserRole> Table_UserRoles { get; set; }

        public static long Table_Claim__PK_CLAIMID = 0;
        public static List<UserClaim> Table_Cliam { get; set; }

        #endregion

        #region ctor(s)

        public UserStoreDAL_InMemory()
        {

        }

        static UserStoreDAL_InMemory()
        {
            Table_User = new List<ApplicationUser>();
            Table_UserLogin = new List<UserLogin>();
            Table_UserRoles = new List<RoleManager.UserRole>();
            Table_Cliam = new List<UserClaim>();
        }

        #endregion

        #region IUserStoreDAL

        #region IUserStore

        public IEnumerable<ApplicationUser> FindById(string Id)
        {
            lock (Table_User)
            {
                return Table_User.Where(u => u.Id == Id);
            }
        }

        public IEnumerable<ApplicationUser> FindByName(string UserName)
        {
            lock (Table_User)
            {
                return Table_User.Where(u => u.UserName == UserName);
            }
        }

        public bool User_Create(ApplicationUser user)
        {
            lock (Table_User)
            {
                user.UserGuid = Guid.NewGuid().ToString();

                user.Id = (Table_User__PK_USERID++).ToString();
                Table_User.Add(user);

                return true;
            }
        }

        public bool User_Delete(ApplicationUser user)
        {
            lock (Table_User)
            {
                return Table_User.Remove(user);
            }
        }

        public bool User_Update(ApplicationUser user)
        {
            lock (Table_User)
            {
                for (int i = 0; i < Table_User.Count; i++)
                {
                    if (Table_User[i].Id == user.Id)
                    {
                        Table_User[i].FirstName = user.FirstName;
                        Table_User[i].LastName = user.LastName;
                        Table_User[i].UserName = user.UserName;
                        Table_User[i].UserGuid = user.UserGuid;
                        Table_User[i].PhoneNumber = user.PhoneNumber;
                        Table_User[i].PhoneConfirmed = user.PhoneConfirmed;
                        Table_User[i].EmailConfirmed = user.EmailConfirmed;
                        Table_User[i].Email = user.Email;
                        Table_User[i].PasswordHash = user.PasswordHash;
                        Table_User[i].AccessFailedCount = user.AccessFailedCount;
                        Table_User[i].LockoutEndDateUtc = user.LockoutEndDateUtc;
                        Table_User[i].LockoutEnabled = user.LockoutEnabled;
                        Table_User[i].SecurityStamp = user.SecurityStamp;
                        Table_User[i].TwoFactorEnabled = user.TwoFactorEnabled;

                        return true;
                    }
                }
            }

            return false;
        }

        #endregion

        #region IUserLoginStore

        public bool AddUserLogin(ApplicationUser user, UserLoginInfo login)
        {
            lock (Table_UserLogin)
            {
                if (Table_UserLogin.Any(l => l.UserId == user.Id && l.LoginProvider == login.LoginProvider && l.ProviderKey == login.ProviderKey))
                {
                    ///TODO:: exception
                    return false;
                }

                Table_UserLogin.Add(new UserLogin(user.Id, login.LoginProvider, login.ProviderKey));
            }

            return true;
        }

        public ApplicationUser FindByLoginUser(UserLoginInfo login)
        {
            lock (Table_User)
            {
                var result = from u in Table_User
                             join u2 in Table_UserLogin on u.Id equals u2.UserId
                             where u2.LoginProvider == login.LoginProvider && u2.ProviderKey == login.ProviderKey
                             select u;

                return result.FirstOrDefault();
            }
        }

        public IEnumerable<UserLoginInfo> GetUserLogins(ApplicationUser login)
        {
            lock (Table_UserLogin)
            {
                return Table_UserLogin
                    .Where(l => l.UserId == login.Id)
                    .Select(u => new UserLoginInfo(u.LoginProvider, u.ProviderKey));
            }
        }

        public bool RemoveUserLogin(ApplicationUser user, UserLoginInfo login)
        {
            lock (Table_UserLogin)
            {
                return Table_UserLogin.RemoveAll(l => l.UserId == user.Id && l.LoginProvider == login.LoginProvider && l.ProviderKey == login.ProviderKey) > 0;
            }
        }

        #endregion

        #region IUserRoleStore

        public string GetRoleId(string roleName)
        {
            lock (RoleManager.DAL.RoleStoreDAL_InMemory.Table_Role)
            {
                var role = RoleManager.DAL.RoleStoreDAL_InMemory.Table_Role.FirstOrDefault(r => r.Name == roleName);
                return role == null ? "" : role.Id;
            }
        }

        public bool InsertRole(ApplicationUser user, string roleName)
        {
            var roleId = GetRoleId(roleName);
            if (String.IsNullOrEmpty(roleId))
                return false;

            var userRole = new RoleManager.UserRole() { UserId = user.Id, RoleId = roleId };

            lock (Table_UserRoles)
            {
                Table_UserRoles.Add(userRole);
            }

            return true;
        }

        public IEnumerable<RoleManager.Role> GetUserRoles(string userId)
        {
            lock (Table_UserRoles)
            {
                var roles = from r in RoleManager.DAL.RoleStoreDAL_InMemory.Table_Role
                            join u2r in Table_UserRoles on r.Id equals u2r.RoleId
                            where u2r.UserId == userId
                            select new RoleManager.Role(r.Name);

                return roles.ToArray();
            }
        }

        public bool IsInRole(string userId, string roleName)
        {
            lock (Table_UserRoles)
            {
                var roles = from r in RoleManager.DAL.RoleStoreDAL_InMemory.Table_Role
                            join u2r in Table_UserRoles on r.Id equals u2r.RoleId
                            where u2r.UserId == userId && r.Name == roleName
                            select 1;

                return roles.Any();
            }
        }

        public bool RemoveRole(ApplicationUser user, string roleName)
        {
            lock (Table_UserRoles)
            {
                var roleId = GetRoleId(roleName);

                var u2r = Table_UserRoles.FirstOrDefault(r => r.RoleId == roleId);
                if (u2r != null)
                {
                    return Table_UserRoles.Remove(u2r);
                }
                else
                {
                    return false;
                }
            }
        }

        #endregion

        #region IUserClaimStore

        public bool User_AddClaim(ApplicationUser user, Claim claim)
        {
            lock (Table_Cliam)
            {
                var c = new UserClaim()
                {
                    UserId = user.Id,
                    ClaimType = claim.Type,
                    ClaimValue = claim.Value
                };

                c.Id = Table_Claim__PK_CLAIMID++;
                Table_Cliam.Add(c);
            }

            return true;
        }

        public IList<Claim> User_GetClaims(string userID)
        {
            lock (Table_Cliam)
            {
                return Table_Cliam
                    .Where(c => c.UserId == userID)
                    .Select(c => new Claim(c.ClaimType, c.ClaimValue))
                    .ToList();
            }
        }

        public bool User_RemoveClaim(ApplicationUser user, Claim claim)
        {
            lock (Table_Cliam)
            {
                var cl = Table_Cliam.FirstOrDefault(c => c.UserId == user.Id && claim.Type == c.ClaimType);
                if (cl != null)
                {
                    return Table_Cliam.Remove(cl);
                }

                return false;
            }
        }

        #endregion

        #region IUserEmailStore

        public IEnumerable<ApplicationUser> GetUserByEmail(string email)
        {
            lock (Table_User)
            {
                return Table_User
                    .Where(u => u.Email == email)
                    .ToArray();
            }
        }

        #endregion

        #endregion

        #region IDisposbale

        public void Dispose()
        {
        }

        #endregion
    }
}
