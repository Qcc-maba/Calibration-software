using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2.Settings;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public interface IIdentityStore : IDisposable
    {
        //User
        Task<PagedResponse<BaseUserExtendView>> FindUsersAsync(string Search, int PageSize, int PageNumber);
        Task<bool> User_CreateAsync(BaseUser user, bool UseDefaultTypes);
        Task<bool> User_DeleteByEmailAsync(string Email);
        Task<bool> User_DeleteByIdAsync(long UserID);
        Task<bool> User_UpdateAsync(BaseUser user, bool UpdateVersion = false);
        Task<BaseUserExtendView> FindByIdAsync(long UserID);
        Task<BaseUserExtendView> FindByLoginUserAsync(UserLoginInfo login);
        Task<BaseUserExtendView> FindByUserNameAsync(string UserName);
        Task<BaseUserExtendView> FindByEmailAsync(string email);
        Task<bool> User_UpdateSecurityStampAsync(long UserID, string SecurityStamp);
        Task<bool> User_UpdatePhoneNumberChangeTokenAsync(long UserID, string VerificationCode);
        Task<PhoneVerificationCode> User_GetPhoneNumberChangeTokenAsync(long UserID);

        //User login providers
        Task<bool> AddUserLoginAsync(long UserID, UserLoginInfo login);
        Task<IEnumerable<UserLoginInfo>> GetUserLoginsAsync(long UserID);
        Task<bool> RemoveUserLoginAsync(long UserID, UserLoginInfo login);

        //Roles
        Task<bool> IsUserHasRoleAsync(long UserID, int roleName);
        Task<Role[]> GetUserRolesAsync(long UserID, int? FilterGroup = null);
        Task<bool> RemoveUserRoleAsync(long UserID, int RoleID);
        Task<bool> Role_CreateAsync(Role role);
        Task<bool> Role_DeleteByIdAsync(int RoleId);
        Task<bool> Role_DeleteByNameAsync(string RoleName);
        Task<Role> Role_FindByIdAsync(int RoleId);
        Task<Role> Role_FindByNameAsync(string RoleName);
        Task<bool> Role_UpdateAsync(Role role);
        Task<bool> UserInsertRoleAsync(long UserID, int RoleID);
        Task<Role[]> System_Role_GetAll(int? FilterGroup);

        //claims
        Task<bool> User_AddClaimAsync(long UserID, UserClaim claim);
        Task<IEnumerable<UserClaim>> User_GetClaimsAsync(long UserID);
        Task<bool> User_RemoveClaimAsync(long UserID, string ClaimType);


        Task<bool> User_UpdateImageAsync(long UserID, string ImageURI);
        Task<SystemTimeZone[]> GetSystemTimeZonesAsync();
        Task<SystemUIFormat[]> GetUIFormatsAsync();
        Task<SystemTemperatureUnit[]> GetSystemTemperatureUnitsAsync();

    }
}
