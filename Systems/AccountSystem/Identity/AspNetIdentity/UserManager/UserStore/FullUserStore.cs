using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager.UserStore
{
    public class FullUserStore :
                 IUserStore<ApplicationUser>,
                 IUserLoginStore<ApplicationUser, string>,
                 IUserRoleStore<ApplicationUser>,
                 IUserPasswordStore<ApplicationUser>,
                 IPasswordHasher,
                 IUserEmailStore<ApplicationUser>,
        //IUserTokenProvider<ApplicationUser, string>,
                 IUserLockoutStore<ApplicationUser, string>,
                 IUserPhoneNumberStore<ApplicationUser, string>,
                 IUserClaimStore<ApplicationUser, string>,
        //IQueryableUserStore<ApplicationUser, string>,
                 IUserSecurityStampStore<ApplicationUser, string>,
                 IUserTwoFactorStore<ApplicationUser, string>
    {
        #region properties

        public DAL.IUserStoreDAL Context { get; private set; }

        #endregion

        #region ctor (s)

        public FullUserStore(DAL.IUserStoreDAL context)
        {
            Context = context;
        }

        #endregion

        #region IUserStore

        public Task<ApplicationUser> FindByIdAsync(string userId)
        {
            Task<ApplicationUser> taskInvoke = Task<ApplicationUser>.Factory.StartNew(() =>
            {
                return Context.FindById(userId).FirstOrDefault();
            });

            return taskInvoke;
        }

        public Task<ApplicationUser> FindByNameAsync(string userName)
        {
            Task<ApplicationUser> taskInvoke = Task<ApplicationUser>.Factory.StartNew(() =>
            {
                return Context.FindByName(userName).FirstOrDefault();
            });

            return taskInvoke;
        }

        public Task CreateAsync(ApplicationUser user)
        {
            return Task.Factory.StartNew(() => Context.User_Create(user));
        }

        public Task DeleteAsync(ApplicationUser user)
        {
            return Task.Factory.StartNew(() => Context.User_Delete(user));
        }

        public Task UpdateAsync(ApplicationUser user)
        {
            return Task.Factory.StartNew(() => Context.User_Update(user));
        }

        #endregion

        #region IUserLoginStore

        public Task AddLoginAsync(ApplicationUser user, UserLoginInfo login)
        {
            return Task.Factory.StartNew(() =>
            {
                return Context.AddUserLogin(user, login);
            });
        }

        public Task<ApplicationUser> FindAsync(UserLoginInfo login)
        {
            Task<ApplicationUser> taskInvoke = Task<ApplicationUser>.Factory.StartNew(() =>
            {
                return Context.FindByLoginUser(login);
            });

            return taskInvoke;
        }

        public Task<IList<UserLoginInfo>> GetLoginsAsync(ApplicationUser user)
        {
            Task<IList<UserLoginInfo>> taskInvoke = Task<IList<UserLoginInfo>>.Factory.StartNew(() =>
            {
                return Context.GetUserLogins(user).ToList();
            });

            return taskInvoke;
        }

        public Task RemoveLoginAsync(ApplicationUser user, UserLoginInfo login)
        {
            return Task.Factory.StartNew(() => Context.RemoveUserLogin(user, login));
        }

        #endregion

        #region IUserPasswordStore

        private string HashAlgorithmPassword(string p)
        {
            ///TODO: get security option from "global" security
            return HashAlgorithmPasswordManagement.ComputeHash(p, "MD5", null);
        }

        public Task<string> GetPasswordHashAsync(ApplicationUser user)
        {
            return Task.FromResult(user.PasswordHash);
        }

        public Task<bool> HasPasswordAsync(ApplicationUser user)
        {
            return Task<bool>.Factory.StartNew(() => !String.IsNullOrEmpty(user.PasswordHash));
        }

        public Task SetPasswordHashAsync(ApplicationUser user, string passwordHash)
        {
            user.PasswordHash = passwordHash;
            return Task.FromResult<object>(null);
        }

        #endregion

        #region IPasswordHasher

        public string HashPassword(string password)
        {
            ///TODO: get from "global" settings
            return HashAlgorithmPasswordManagement.ComputeHash(password, "MD5", null);
        }

        public PasswordVerificationResult VerifyHashedPassword(string hashedPassword, string providedPassword)
        {
            ///TODO: get from "global" settings
            return HashAlgorithmPasswordManagement.VerifyHash(providedPassword, "MD5", hashedPassword) ?
                PasswordVerificationResult.Success : PasswordVerificationResult.Failed;
        }

        #endregion

        #region IUserRoleStore

        public Task AddToRoleAsync(ApplicationUser user, string roleName)
        {
            if (user == null)
            {
                throw new ArgumentNullException("user");
            }

            if (string.IsNullOrEmpty(roleName))
            {
                throw new ArgumentException("Argument cannot be null or empty: roleName.");
            }

            return Task.Factory.StartNew(() => Context.InsertRole(user, roleName));
        }

        public Task<IList<string>> GetRolesAsync(ApplicationUser user)
        {
            if (user == null)
            {
                throw new ArgumentNullException("user");
            }

            return Task.FromResult<IList<string>>(
                Context.GetUserRoles(user.Id)
                .Select(s => s.Name)
                .ToList());
        }

        public Task<bool> IsInRoleAsync(ApplicationUser user, string roleName)
        {
            if (user == null)
            {
                throw new ArgumentNullException("user");
            }

            if (string.IsNullOrEmpty(roleName))
            {
                throw new ArgumentException("Argument cannot be null or empty: roleName.");
            }

            return Task.Factory.StartNew(() => Context.IsInRole(user.Id, roleName));
        }

        public Task RemoveFromRoleAsync(ApplicationUser user, string roleName)
        {
            if (user == null)
            {
                throw new ArgumentNullException("user");
            }

            if (string.IsNullOrEmpty(roleName))
            {
                throw new ArgumentException("Argument cannot be null or empty: roleName.");
            }

            return Task.Factory.StartNew(() => Context.RemoveRole(user, roleName));
        }

        #endregion

        #region IUserClaimStore

        public Task AddClaimAsync(ApplicationUser user, Claim claim)
        {
            return Task.Factory.StartNew(() => Context.User_AddClaim(user, claim));
        }

        public Task<IList<Claim>> GetClaimsAsync(ApplicationUser user)
        {
            return Task<IList<Claim>>.Factory.StartNew(() => Context.User_GetClaims(user.Id));
        }

        public Task RemoveClaimAsync(ApplicationUser user, Claim claim)
        {
            return Task.Factory.StartNew(() => Context.User_RemoveClaim(user, claim));
        }

        #endregion

        #region IUserEmailStore

        public Task<ApplicationUser> FindByEmailAsync(string email)
        {
            if (String.IsNullOrEmpty(email))
            {
                throw new ArgumentNullException("email");
            }

            return Task.FromResult(Context.GetUserByEmail(email).FirstOrDefault());
        }

        public Task<string> GetEmailAsync(ApplicationUser user)
        {
            return Task.FromResult(user.Email);
        }

        public Task<bool> GetEmailConfirmedAsync(ApplicationUser user)
        {
            return Task.FromResult(user.EmailConfirmed);
        }

        public Task SetEmailAsync(ApplicationUser user, string email)
        {
            return Task.Factory.StartNew(() => user.Email = email);
        }

        public Task SetEmailConfirmedAsync(ApplicationUser user, bool confirmed)
        {
            return Task.Factory.StartNew(() => user.EmailConfirmed = confirmed);
        }

        #endregion

        #region IUserLockoutStore

        public Task<int> GetAccessFailedCountAsync(ApplicationUser user)
        {
            return Task.FromResult(user.AccessFailedCount);
        }

        public Task<bool> GetLockoutEnabledAsync(ApplicationUser user)
        {
            return Task.FromResult(user.LockoutEnabled);
        }

        public Task<DateTimeOffset> GetLockoutEndDateAsync(ApplicationUser user)
        {
            return
                Task.FromResult(user.LockoutEndDateUtc.HasValue
                    ? new DateTimeOffset(DateTime.SpecifyKind(user.LockoutEndDateUtc.Value, DateTimeKind.Utc))
                    : new DateTimeOffset()); ;
        }

        public Task<int> IncrementAccessFailedCountAsync(ApplicationUser user)
        {
            return Task.FromResult(user.AccessFailedCount++);
        }

        public Task ResetAccessFailedCountAsync(ApplicationUser user)
        {
            user.AccessFailedCount = 0;
            return Task.FromResult<object>(null);
        }

        public Task SetLockoutEnabledAsync(ApplicationUser user, bool enabled)
        {
            user.LockoutEnabled = enabled;

            return Task.FromResult<object>(null);
        }

        public Task SetLockoutEndDateAsync(ApplicationUser user, DateTimeOffset lockoutEnd)
        {
            user.LockoutEndDateUtc = lockoutEnd.UtcDateTime;
            return Task.FromResult<object>(null);
        }

        #endregion

        #region IUserTokenProvider

        //public Task<string> GenerateAsync(string purpose, UserManager<ApplicationUser, string> manager, ApplicationUser user)
        //{
        //    throw new NotImplementedException();
        //}

        //public Task<bool> IsValidProviderForUserAsync(UserManager<ApplicationUser, string> manager, ApplicationUser user)
        //{
        //    throw new NotImplementedException();
        //}

        //public Task NotifyAsync(string token, UserManager<ApplicationUser, string> manager, ApplicationUser user)
        //{
        //    throw new NotImplementedException();
        //}

        //public Task<bool> ValidateAsync(string purpose, string token, UserManager<ApplicationUser, string> manager, ApplicationUser user)
        //{
        //    throw new NotImplementedException();
        //}

        #endregion

        #region IUserPhoneNumberStore

        public Task<string> GetPhoneNumberAsync(ApplicationUser user)
        {
            return Task.Factory.StartNew(() => user.PhoneNumber);
        }

        public Task<bool> GetPhoneNumberConfirmedAsync(ApplicationUser user)
        {
            return Task.Factory.StartNew(() => user.PhoneConfirmed); ;
        }

        public Task SetPhoneNumberAsync(ApplicationUser user, string phoneNumber)
        {
            user.PhoneNumber = phoneNumber;
            return Task.FromResult<object>(null);
        }

        public Task SetPhoneNumberConfirmedAsync(ApplicationUser user, bool confirmed)
        {
            user.PhoneConfirmed = confirmed;
            return Task.FromResult<object>(null);
        }

        #endregion

        #region IQueryableUserStore

        //public IQueryable<ApplicationUser> Users
        //{
        //    get { throw new NotImplementedException(); }
        //}

        #endregion

        #region IUserSecurityStampStore

        public Task<string> GetSecurityStampAsync(ApplicationUser user)
        {
            return Task.FromResult(user.SecurityStamp);
        }

        public Task SetSecurityStampAsync(ApplicationUser user, string stamp)
        {
            user.SecurityStamp = stamp;
            return Task.FromResult<object>(null);
        }

        #endregion

        #region IUserTwoFactorStore

        public Task<bool> GetTwoFactorEnabledAsync(ApplicationUser user)
        {
            return Task.FromResult(user.TwoFactorEnabled);
        }

        public Task SetTwoFactorEnabledAsync(ApplicationUser user, bool enabled)
        {
            user.TwoFactorEnabled = enabled;
            return Task.FromResult<object>(null);
        }

        #endregion

        #region IDisposable

        public void Dispose()
        {
        }

        #endregion
    }
}

