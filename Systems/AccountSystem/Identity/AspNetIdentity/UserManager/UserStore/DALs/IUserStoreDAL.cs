using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager.UserStore.DAL
{
    public interface IUserStoreDAL : IDisposable
    {
        #region IUserStore

        IEnumerable<ApplicationUser> FindById(string Id);

        IEnumerable<ApplicationUser> FindByName(string UserName);

        bool User_Create(ApplicationUser user);

        bool User_Delete(ApplicationUser user);

        bool User_Update(ApplicationUser user);

        #endregion

        #region IUserLoginStore

        bool AddUserLogin(ApplicationUser user, UserLoginInfo login);
        
        bool RemoveUserLogin(ApplicationUser user, UserLoginInfo login);
        
        ApplicationUser FindByLoginUser(UserLoginInfo login);

        IEnumerable<UserLoginInfo> GetUserLogins(ApplicationUser user);

        #endregion

        #region IUserRoleStore

        string GetRoleId(string roleName);

        bool InsertRole(ApplicationUser user, string roleName);

        IEnumerable<RoleManager.Role> GetUserRoles(string userId);

        bool IsInRole(string userId, string roleName);

        bool RemoveRole(ApplicationUser user, string roleName);

        #endregion

        #region IUserClaimStore

        bool User_AddClaim(ApplicationUser user, System.Security.Claims.Claim claim);

        IList<System.Security.Claims.Claim> User_GetClaims(string userID);

        bool User_RemoveClaim(ApplicationUser user, System.Security.Claims.Claim claim);

        #endregion

        #region IUserEmailStore

        IEnumerable<ApplicationUser> GetUserByEmail(string email);

        #endregion
    }
}
