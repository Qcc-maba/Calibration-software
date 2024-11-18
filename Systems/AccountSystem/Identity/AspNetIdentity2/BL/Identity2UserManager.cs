using System;
using Microsoft.Owin.Security;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL
{
    public class Identity2UserManager : IDisposable
    {
        #region CONSTANTS

        private const string ENCRYPTION_PURPOSE__CONFIRM_EMAIL = "CONFIRM_EMAIL";
        private const string ENCRYPTION_PURPOSE__RESET_PASSWORD = "RESET_PASSWORD";

        #endregion

        #region members

        private DAL.IIdentityStore _StoreBacked = null;
        private DAL.IIdentityStore _Store
        {
            get
            {
                if (_StoreBacked == null)
                {
                    _StoreBacked = _StoreGeneratorFunc();
                }
                return _StoreBacked;
            }
        }
        private Func<DAL.IIdentityStore> _StoreGeneratorFunc = null;

        #endregion

        #region properties

        public Settings.ManagerSettings ManagerOptions { get; private set; }
        public Connectors.OWINLibrary.Security.DataProtectionProviderSettings DataProtectionOptions { get; private set; }

        #endregion

        #region ctor

        public Identity2UserManager(Func<DAL.IIdentityStore> storeGeneratorFunc, Settings.ManagerSettings managerOptions = null, Connectors.OWINLibrary.Security.DataProtectionProviderSettings dataProtectionOptions = null)
        {
            _StoreGeneratorFunc = storeGeneratorFunc;

            DataProtectionOptions = dataProtectionOptions ?? new Connectors.OWINLibrary.Security.DataProtectionProviderSettings();
            ManagerOptions = managerOptions ?? new Settings.ManagerSettings();
        }

        public Identity2UserManager(DAL.IIdentityStore store, Settings.ManagerSettings managerOptions = null, Connectors.OWINLibrary.Security.DataProtectionProviderSettings dataProtectionOptions = null)
        {
            _StoreBacked = store;

            DataProtectionOptions = dataProtectionOptions ?? new Connectors.OWINLibrary.Security.DataProtectionProviderSettings();
            ManagerOptions = managerOptions ?? new Settings.ManagerSettings();
        }

        #endregion

        #region private methods

        private async Task UserLoginFailed(DAL.BaseUserExtendView user)
        {
            user.AccessFailedCount++;
            user.LastFailedLoginDateUtc = DateTime.UtcNow;

            if (!user.LockoutEnabled
                && !user.LockoutEndDateUtc.HasValue
                && user.AccessFailedCount >= this.ManagerOptions.AccessFailedCount_MaxAttempts)
            {
                user.LockoutEnabled = true;
                user.LockoutEndDateUtc = DateTime.UtcNow.Add(this.ManagerOptions.AccessFailedCount_BlockPeriod);
            }

            await _User_UpdateAsync(user);
        }

        private async Task<ActionResult<Models.ApplicationUserModel>> ValidateLoginProccess(DAL.BaseUserExtendView user, string password, bool RecordAsLogin)
        {
            bool RejectLogin = false;

            #region LockoutEnabled :: verify user isn't already locked-out

            if (user.LockoutEnabled)
            {
                //temp lockout
                if (user.LockoutEndDateUtc.HasValue)
                {
                    //verify period has expired
                    if (DateTime.UtcNow < user.LockoutEndDateUtc.Value)
                    {
                        RejectLogin = true;
                    }
                }
                else
                {
                    RejectLogin = true;
                }

                if (RejectLogin)
                {
                    await UserLoginFailed(user);

                    return new ActionResult<Models.ApplicationUserModel>(false, Resources.UserIsBlocked);
                }
            }

            #endregion

            #region verify Email confirmed

            if (!user.EmailConfirmed)
            {
                await UserLoginFailed(user);
                return new ActionResult<Models.ApplicationUserModel>(false, String.Format(Resources.EmailNotConfirmed, user.Email));
            }

            #endregion

            #region verify password

            if (!Crypto.VerifyHashedPassword(user.PasswordHash, password))
            {
                RejectLogin = true;

                await UserLoginFailed(user);

                //return error
                return new ActionResult<Models.ApplicationUserModel>(false, Resources.PasswordMismatch);
            }

            #endregion

            if (RecordAsLogin)
            {
                user.LastLoginDateUtc = DateTime.UtcNow;

                //reset failures (keep [LastFailedLoginDateUtc] value)
                user.LockoutEnabled = false;
                user.LockoutEndDateUtc = null;
                user.AccessFailedCount = 0;
                user.UpdateVersion++;
                await _User_UpdateAsync(user, true);
            }

            return new ActionResult<Models.ApplicationUserModel>(new Models.ApplicationUserModel(user));
        }

        private string GenerateSecurityStamp(DAL.BaseUser user = null)
        {
            var newStamp = Guid.NewGuid().ToString().Substring(0, 10);

            if (user != null)
            {
                user.SecurityStamp = newStamp;
            }

            return newStamp;
        }

        private bool VerifyHashedPassword(string hashedPassword, string password)
        {
            var result = Crypto.VerifyHashedPassword(hashedPassword, password);
            return result;
        }

        private string HashPassowrd(string password)
        {
            var hasedPassword = Crypto.HashPassword(password);
            return hasedPassword;
        }

        private async Task<ActionResult> _User_UpdateAsync(DAL.BaseUser updatedUser, bool UpdateVersion = false)
        {
            GenerateSecurityStamp(updatedUser);

            var result = await _Store.User_UpdateAsync(updatedUser, UpdateVersion);

            return result ? ActionResult.Success : new ActionResult(false);
        }

        #endregion

        #region Identity Methods

        #region System

        public async Task<ActionResult<Models.UserRoleModel[]>> System_RoleModels(int? FilterGroup = null)
        {
            var zones = await this._Store.System_Role_GetAll(FilterGroup);

            var _zones = zones
                        .Select(z => new Models.UserRoleModel(z))
                        .ToArray();

            return new ActionResult<Models.UserRoleModel[]>(_zones);
        }
        public async Task<ActionResult<Models.SystemTimeZoneModel[]>> System_TimeZonesAsync()
        {
            var zones = await this._Store.GetSystemTimeZonesAsync();
            var _zones = zones
                        .Select(z => new Models.SystemTimeZoneModel(z))
                        .ToArray();

            return new ActionResult<Models.SystemTimeZoneModel[]>(_zones);
        }

        public async Task<ActionResult<Models.SystemUIFormatModel[]>> System_UIFormatsAsync()
        {
            var uiFormats = await this._Store.GetUIFormatsAsync();
            var _uiFormats = uiFormats
                        .Select(z => new Models.SystemUIFormatModel(z))
                        .ToArray();

            return new ActionResult<Models.SystemUIFormatModel[]>(_uiFormats);
        }

        public async Task<ActionResult<Models.SystemTemperatureUnitModel[]>> System_TemperatureUnitsAsync()
        {
            var tempUnits = await this._Store.GetSystemTemperatureUnitsAsync();
            var _tempUnits = tempUnits
                            .Select(z => new Models.SystemTemperatureUnitModel(z))
                            .ToArray();

            return new ActionResult<Models.SystemTemperatureUnitModel[]>(_tempUnits);
        }

        #endregion

        #region User

        public async Task<ActionPagedResult<Models.ApplicationUserModel>> SearchUsersAsync(string search, int PageSize, int PageNumber)
        {
            var findUsers = await this._Store.FindUsersAsync(search, PageSize, PageNumber);

            if (findUsers != null)
            {
                var users = findUsers.Items
                                        .Select(u => new Models.ApplicationUserModel(u))
                                        .ToArray();

                return new ActionPagedResult<Models.ApplicationUserModel>(users)
                {
                    RequestedPageNumber = findUsers.RequestedPageNumber,
                    RequestedPageSize = findUsers.RequestedPageSize,
                    TotalItems = findUsers.TotalItems
                };
            }
            else
            {
                return new ActionPagedResult<Models.ApplicationUserModel>();
            }
        }

        public async Task<ActionResult> User_ChangeLockoutUserAsync(string Email, bool Lockout, DateTime? BlockPeriod = null)
        {
            var existsUser = await this._Store.FindByEmailAsync(Email);

            if (existsUser == null)
            {
                return new ActionResult(false);
            }

            if (Lockout)
            {
                existsUser.LockoutEnabled = true;
                existsUser.LockoutEndDateUtc = BlockPeriod;
            }
            else
            {
                existsUser.AccessFailedCount = 0;
                existsUser.LockoutEnabled = false;
                existsUser.LockoutEndDateUtc = null;
            }

            return await this._User_UpdateAsync(existsUser, true);
        }

        public async Task<ActionResult> User_ImageUploadAsync(long UserID, string img_url)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<string>(Resources.UserIdNotFound);
            }

            var updateResult = await this._Store.User_UpdateImageAsync(UserID, img_url);
            if (updateResult)
            {
                updateResult = await this._Store.User_UpdateSecurityStampAsync(UserID, GenerateSecurityStamp(user));
                if (updateResult)
                {
                    return new ActionResult(true);
                }
            }

            return new ActionResult(false, Resources.DefaultError);
        }

        public async Task<ActionResult<string>> User_GenerateChangePhoneConfirmationTokenAsync(long UserID, string NewPhoneNumber)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<string>(Resources.UserIdNotFound);
            }

            var tokenObj = new Identity2.Security.ChangePhoneData()
            {
                NewPhoneNumber = NewPhoneNumber
            };

            var rand = new Random();
            var token = rand.Next(10000, 99999).ToString();

            var updateToken = await this._Store.User_UpdatePhoneNumberChangeTokenAsync(UserID, token);

            return new ActionResult<string>(updateToken)
            {
                Result = token
            };

        }

        public async Task<ActionResult> User_ChangePhoneNumberAsync(long UserID, string NewPhoneNumber, string NewPhoneVerficationCode)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<string>(Resources.UserIdNotFound);
            }

            var tokenObj = new Identity2.Security.ChangePhoneData()
            {
                NewPhoneNumber = NewPhoneNumber
            };

            var updateToken = await this._Store.User_GetPhoneNumberChangeTokenAsync(UserID);
            if (updateToken == null || updateToken.PhoneNumberChangeToken != NewPhoneVerficationCode)
            {
                return new ActionResult(false, Resources.InvalidToken);
            }
            else
            {
                user.PhoneConfirmed = true;
                user.PhoneNumber = NewPhoneNumber;

                var updateResult = await this._User_UpdateAsync(user, true);
                if (updateResult.Succeeded)
                {
                    //reset token (it's one time use!)
                    await this._Store.User_UpdatePhoneNumberChangeTokenAsync(UserID, null);

                    return new ActionResult(true);
                }
                else
                {
                    return updateResult;
                }
            }
        }

        public async Task<ActionResult<string>> User_GeneratePasswordResetTokenAsync(long UserID)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<string>(Resources.UserIdNotFound);
            }

            //decrypt token
            var provider = this.DataProtectionOptions.CreateDataProtectionProvider();
            var dataProtoctor = provider.Create(ENCRYPTION_PURPOSE__RESET_PASSWORD);
            var tokenGenerator = new Security.ResetPasswordFormater(dataProtoctor);

            var tokenObj = new Identity2.Security.ResetPasswordData()
            {
                Email = user.Email,
                UserID = UserID,
                ExpireDate = DateTime.UtcNow.AddDays(7),
                IssueDate = DateTime.UtcNow
            };

            var token = tokenGenerator.Protect2String(tokenObj);

            return new ActionResult<string>(token);
        }

        public async Task<ActionResult> User_ResetPasswordAsync(long UserID, string ResetPasswordToken, string NewPassword)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<string>(Resources.UserIdNotFound);
            }

            #region validate password policy

            var passwordValidator = new Validators.PasswordValidator(this.ManagerOptions.PasswordValidatorOptions);
            var validatePasswordResult = await passwordValidator.ValidateAsync(NewPassword);
            if (!validatePasswordResult.Succeeded)
            {
                return validatePasswordResult;
            }

            #endregion

            //decrypt token
            var provider = this.DataProtectionOptions.CreateDataProtectionProvider();
            var dataProtoctor = provider.Create(ENCRYPTION_PURPOSE__RESET_PASSWORD);
            var tokenGenerator = new Security.ResetPasswordFormater(dataProtoctor);

            try
            {
                var token = tokenGenerator.Unprotect(ResetPasswordToken);
                if (token.ExpireDate < DateTime.UtcNow || token.UserID != UserID || token.Email != user.Email)
                {
                    return new ActionResult(false, Resources.InvalidToken);
                }
                else
                {
                    user.PasswordHash = HashPassowrd(NewPassword);

                    var updateResult = await this._User_UpdateAsync(user);
                    if (updateResult.Succeeded)
                    {
                        return new ActionResult(true);
                    }
                }
            }
            catch
            {
                return new ActionResult(false, Resources.InvalidToken);
            }

            return new ActionResult(false);
        }

        public async Task<ActionResult> User_ConfirmEmailAsync(string Email, string ConfirmEmailToken)
        {
            var user = await this._Store.FindByEmailAsync(Email);
            if (user == null)
            {
                return new ActionResult<string>(false, String.Format(Resources.InvalidEmail, Email));
            }

            //decrypt token
            var provider = this.DataProtectionOptions.CreateDataProtectionProvider();
            var dataProtoctor = provider.Create(ENCRYPTION_PURPOSE__CONFIRM_EMAIL);
            var tokenGenerator = new Security.ConfirmEmailFormater(dataProtoctor);

            try
            {
                var token = tokenGenerator.Unprotect(ConfirmEmailToken, ENCRYPTION_PURPOSE__CONFIRM_EMAIL);

                if (token.ExpireDate < DateTime.UtcNow || token.Email != Email)
                {
                    return new ActionResult(false, Resources.InvalidToken);
                }
                else
                {
                    user.EmailConfirmed = true;

                    var updateResult = await this._User_UpdateAsync(user);
                    if (updateResult.Succeeded)
                    {
                        return new ActionResult(true);
                    }
                }
            }
            catch
            {
                return new ActionResult(false, Resources.DefaultError);
            }

            return new ActionResult(false, Resources.DefaultError);

        }

        public async Task<ActionResult<string>> User_GenerateEmailConfirmationTokenAsync(long UserID)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<string>(Resources.UserIdNotFound);
            }

            return await User_GenerateEmailConfirmationTokenAsync(user.Email);
        }

        public async Task<ActionResult<string>> User_GenerateEmailConfirmationTokenAsync(string UserEmail)
        {
            var tokenObj = new Identity2.Security.ConfirmEmailData()
            {
                Email = UserEmail, //<- this is the email we would like to confirm
                ExpireDate = DateTime.UtcNow.AddDays(7),
                IssueDate = DateTime.UtcNow
            };

            //encrypt token
            var provider = this.DataProtectionOptions.CreateDataProtectionProvider();
            var dataProtoctor = provider.Create(ENCRYPTION_PURPOSE__CONFIRM_EMAIL);
            var tokenGenerator = new Security.ConfirmEmailFormater(dataProtoctor);

            var token = tokenGenerator.Protect2String(tokenObj, ENCRYPTION_PURPOSE__CONFIRM_EMAIL);

            return new ActionResult<string>(token);
        }

        public async Task<ActionResult> User_ChangePasswordAsync(long userID, string OldPassword, string NewPassword)
        {
            //get user
            var user = await this._Store.FindByIdAsync(userID);
            if (user == null)
            {
                return new ActionResult(false, Resources.UserIdNotFound);
            }

            //validate [OldPassword]
            //wrong OldPassword will be recorded in [AccessFailedCount], [LockoutEnabled] and [LockoutEndDateUtc]
            var validate = await ValidateLoginProccess(user, OldPassword, false);

            user.PasswordHash = HashPassowrd(NewPassword);
            var result = await this._User_UpdateAsync(user);

            return new ActionResult(result.Succeeded);
        }

        public async Task<ActionResult> User_ResetPasswordAsync(long userID, string NewPassword)
        {
            //get user
            var user = await this._Store.FindByIdAsync(userID);
            if (user == null)
            {
                return new ActionResult(false, Resources.UserIdNotFound);
            }

            user.PasswordHash = HashPassowrd(NewPassword);
            var result = await this._User_UpdateAsync(user);

            return new ActionResult(result.Succeeded);
        }

        public async Task<ActionResult<Models.ApplicationUserModel>> User_FindByLoginAsync(Models.UserLoginInfoModel userLoginInfo)
        {
            var user = await this._Store.FindByLoginUserAsync(userLoginInfo.ToDAL());

            if (user == null)
            {
                return new ActionResult<Models.ApplicationUserModel>(false, Resources.UserIdNotFound);
            }

            return new ActionResult<Models.ApplicationUserModel>(new Models.ApplicationUserModel(user));
        }

        public async Task<ActionResult<Models.ApplicationUserModel>> User_FindByIDAsync(long UserID)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<Models.ApplicationUserModel>(false, Resources.UserIdNotFound);
            }

            return new ActionResult<Models.ApplicationUserModel>(new Models.ApplicationUserModel(user));
        }

        public async Task<ActionResult<Models.ApplicationUserModel>> User_FindByEmailAsync(string Email, string password)
        {
            //find user
            var user = await this._Store.FindByEmailAsync(Email);
            if (user == null)
            {
                return new ActionResult<Models.ApplicationUserModel>(false, String.Format(Resources.InvalidEmail, Email));
            }

            return await ValidateLoginProccess(user, password, true);
        }

        public async Task<ActionResult<Models.ApplicationUserModel>> User_FindByUserNameAsync(string Username, string password)
        {
            var user = await this._Store.FindByUserNameAsync(Username);
            if (user == null)
            {
                return new ActionResult<Models.ApplicationUserModel>(false, String.Format(Resources.UserNameNotFound, Username));
            }

            return await ValidateLoginProccess(user, password, true);
        }

        public async Task<ActionResult<Models.ApplicationUserModel>> User_FindByUserNameAsync(string UserName)
        {
            var user = await this._Store.FindByUserNameAsync(UserName);
            if (user == null)
            {
                return new ActionResult<Models.ApplicationUserModel>(false, String.Format(Resources.UserNameNotFound, UserName));
            }

            return new ActionResult<Models.ApplicationUserModel>(new Models.ApplicationUserModel(user));
        }

        public async Task<ActionResult<Models.ApplicationUserModel>> User_FindByEmailAsync(string Email)
        {
            var user = await this._Store.FindByEmailAsync(Email);

            if (user == null)
            {
                return new ActionResult<Models.ApplicationUserModel>(false, String.Format(Resources.InvalidEmail, Email));
            }

            return new ActionResult<Models.ApplicationUserModel>(new Models.ApplicationUserModel(user));
        }

        public async Task<ActionResult> User_CreateAsync(Models.CreateUserModel NewUser, bool UseDefaultTypes = false, string password = null)
        {
            var newDALUser = NewUser.CreateDAL();

            if (!String.IsNullOrEmpty(password))
            {
                var passwordValidator = new Validators.PasswordValidator(this.ManagerOptions.PasswordValidatorOptions);
                var validatePasswordResult = await passwordValidator.ValidateAsync(password);
                if (!validatePasswordResult.Succeeded)
                {
                    return validatePasswordResult;
                }

                newDALUser.PasswordHash = HashPassowrd(password);
            }

            #region validate Email is free of use

            var existsUser_byEmail = await _Store.FindByEmailAsync(newDALUser.Email);
            if (existsUser_byEmail != null)
            {
                return new ActionResult(false, String.Format(Resources.DuplicateEmail, newDALUser.Email));
            }

            var existsUser_byUsername = await _Store.FindByEmailAsync(newDALUser.UserName);
            if (existsUser_byUsername != null)
            {
                return new ActionResult(false, String.Format(Resources.DuplicateName, newDALUser.UserName));
            }

            #endregion

            #region prepare user

            newDALUser.UserName = newDALUser.UserName ?? newDALUser.Email;
            newDALUser.UserGuid = String.Format("{0}::{1}", DateTime.UtcNow.Ticks, Guid.NewGuid().ToString());

            #endregion

            GenerateSecurityStamp(newDALUser);

            var result = await _Store.User_CreateAsync(newDALUser, UseDefaultTypes);

            if (result)
            {
                NewUser.UserID = newDALUser.UserID;
                return ActionResult.Success;
            }
            else
            {
                return new ActionResult(false);
            }
        }

        public async Task<ActionResult> User_DeleteAsync(long UserID, string Email)
        {
            var result = await _Store.User_DeleteByEmailAsync(Email);

            return result ? ActionResult.Success : new ActionResult(false);
        }

        public async Task<ActionResult> User_UpdateAsync(Models.UpdateUserModel updatedUser)
        {
            var existsUser = await this._Store.FindByEmailAsync(updatedUser.Email);

            //allow changing only these properties...
            existsUser.FirstName = updatedUser.FirstName;
            existsUser.LastName = updatedUser.LastName;
            existsUser.PhoneNumber = updatedUser.PhoneNumber;

            if (updatedUser.UIFormatID != existsUser.UIFormatID)
            {
                existsUser.UIFormatID = updatedUser.UIFormatID;
                existsUser.LongDatePattern = null;
                existsUser.LongTimePattern = null;
                existsUser.ShortDatePattern = null;
                existsUser.ShortTimePattern = null;
            }
            else
            {
                existsUser.LongDatePattern = updatedUser.LongDatePattern;
                existsUser.LongTimePattern = updatedUser.LongTimePattern;
                existsUser.ShortDatePattern = updatedUser.ShortDatePattern;
                existsUser.ShortTimePattern = updatedUser.ShortTimePattern;
            }
            existsUser.TimeZoneID = updatedUser.TimeZoneID;
            existsUser.TemperatureUnitID = updatedUser.TemperatureUnitID;

            existsUser.City = updatedUser.City;
            existsUser.Country = updatedUser.Country;
            existsUser.StreetName = updatedUser.StreetName;
            existsUser.StreetNo = updatedUser.StreetNo;
            existsUser.ZipCode = updatedUser.ZipCode;

            existsUser.UpdateVersion++;
            return await this._User_UpdateAsync(existsUser, true);
        }

        //Logins
        public async Task<ActionResult> UserLogin_AddAsync(long UserID, Models.UserLoginInfoModel userLoginInfo)
        {
            var existsLogin = await this.UserLogin_GetAllAsync(UserID);
            if (existsLogin.Succeeded && existsLogin.Result.Any(l => l.LoginProvider == userLoginInfo.LoginProvider && l.ProviderKey == userLoginInfo.ProviderKey))
            {
                return new ActionResult(true);
            }

            var result = await this._Store.AddUserLoginAsync(UserID, userLoginInfo.ToDAL());

            if (result)
            {
                result = await this._Store.User_UpdateSecurityStampAsync(UserID, GenerateSecurityStamp());

                if (result)
                {
                    return ActionResult.Success;
                }
            }

            return new ActionResult(false);
        }

        public async Task<ActionResult<Models.UserLoginInfoModel[]>> UserLogin_GetAllAsync(long UserID)
        {
            var user = await this._Store.FindByIdAsync(UserID);
            if (user == null)
            {
                return new ActionResult<Models.UserLoginInfoModel[]>(false, Resources.UserIdNotFound);
            }

            var logins = await this._Store.GetUserLoginsAsync(UserID);

            var _logins = logins
                            .Select(l => new Models.UserLoginInfoModel(l))
                            .ToArray();

            return new ActionResult<Models.UserLoginInfoModel[]>(_logins);
        }

        public async Task<ActionResult> UserLogin_RemoveAsync(long UserID, Models.UserLoginInfoModel userLoginInfo)
        {
            var result = await this._Store.RemoveUserLoginAsync(UserID, userLoginInfo.ToDAL());

            if (result)
            {
                result = await this._Store.User_UpdateSecurityStampAsync(UserID, GenerateSecurityStamp());

                if (result)
                {
                    return ActionResult.Success;
                }
            }

            return new ActionResult(false);
        }

        //Claims
        public async Task<ActionResult<Models.UserClaimModel[]>> UserClaim_GetAllAsync(long UserID)
        {
            var claims = await this._Store.User_GetClaimsAsync(UserID);

            var _claims = claims
                            .Select(s => new Models.UserClaimModel(s))
                            .ToArray();

            return new ActionResult<Models.UserClaimModel[]>(_claims);
        }

        public async Task<ActionResult> UserClaim_AddAsync(long UserID, IEnumerable<Models.UserClaimModel> newClaims)
        {
            bool result = true;
            foreach (var c in newClaims)
            {
                result = result && await this._Store.User_AddClaimAsync(UserID, c.ToDAL());
            }

            if (result)
            {
                result = await this._Store.User_UpdateSecurityStampAsync(UserID, GenerateSecurityStamp());

                if (result)
                {
                    return ActionResult.Success;
                }
            }

            return new ActionResult(false);
        }

        public async Task<ActionResult> UserClaim_RemoveAsync(long UserID, string ClaimType)
        {
            var result = await this._Store.User_RemoveClaimAsync(UserID, ClaimType);

            if (result)
            {
                result = await this._Store.User_UpdateSecurityStampAsync(UserID, GenerateSecurityStamp());

                if (result)
                {
                    return ActionResult.Success;
                }
            }

            return new ActionResult(false);
        }

        //Roles
        public async Task<ActionResult<IEnumerable<Models.UserRoleModel>>> UserRoles_Roles(long UserID, int? FilterGroup = null)
        {
            var roles = await this._Store.GetUserRolesAsync(UserID, FilterGroup);
            var _roles = roles
                .Select(r => new Models.UserRoleModel(r))
                .ToArray();

            return new ActionResult<IEnumerable<Models.UserRoleModel>>(_roles);
        }

        public async Task<ActionResult> UserRoles_UpdateAsync(long TargetUserID, IEnumerable<Models.UpdatedUserRoleModel> UpdatedRoles)
        {
            bool result = true;
            //add new roles (exists in admin and not in user)
            foreach (var role in UpdatedRoles)
            {
                if (role.Add)
                {
                    result = result && await this._Store.UserInsertRoleAsync(TargetUserID, role.RoleID);

                }
                else if (role.Remove)
                {
                    result = result && await this._Store.RemoveUserRoleAsync(TargetUserID, role.RoleID);

                }
            }

            return new ActionResult(result);
        }

        #endregion

        #endregion

        #region IDisposable members

        public void Dispose()
        {
            if (_StoreBacked != null)
            {
                _StoreBacked.Dispose();
                _StoreBacked = null;
            }
        }

        #endregion
    }
}
