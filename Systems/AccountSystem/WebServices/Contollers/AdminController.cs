using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Web.Http;
using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Models;

namespace Maba.AccountSystem.WebServices.Contollers
{
    [RoutePrefix("Admin")]
    [OWIN.Security.Attributes.HostFilterAuthorize(
        RolesCodes = new int[] { Identity2.BL.IdentityConstants.ROLE_PRINCIPAL__SuperAdmin })]
    public class AdminController : BaseController
    {
        [HttpGet]
        [Route("Users")]
        public async Task<CommonWebAPI.Models.PagedResponse<Identity2.BL.Models.ApplicationUserModel>> GetPagedUsers(string search, int PageSize, int pageNumber)
        {
            return await this.HandlePagedResponseTask(async () =>
            {
                var searchResult = await this.UserManager.SearchUsersAsync(search, PageSize, pageNumber);

                if (searchResult.Succeeded)
                {
                    return new PagedResponse<Identity2.BL.Models.ApplicationUserModel>()
                    {
                        TotalItems = searchResult.TotalItems,
                        RequestedPageSize = searchResult.RequestedPageSize,
                        RequestedPageNumber = searchResult.RequestedPageNumber,
                        Body = searchResult.Result
                    };
                }
                else
                {
                    return new PagedResponse<Identity2.BL.Models.ApplicationUserModel>()
                    {
                        TotalItems = 0,
                        RequestedPageSize = searchResult.RequestedPageSize,
                        RequestedPageNumber = searchResult.RequestedPageNumber,
                        Body = new AspNetIdentity.Identity2.BL.Models.ApplicationUserModel[0]
                    };
                }
            });
        }

        [HttpGet]
        [Route("User")]
        public async Task<CommonWebAPI.Models.Response<Models.ApplicationDetailedUserModel>> GetUser(string UserEmail)
        {
            return await this.HandleResponseTask(async () =>
            {
                var getUserResult = await UserManager.User_FindByEmailAsync(UserEmail);

                if (getUserResult != null && getUserResult.Succeeded)
                {
                    getUserResult.Result.ImgURL = this.Carrier.ProfilesSettings.CorrectImageUri(getUserResult.Result.ImgURL);

                    var getClaimsResult = await UserManager.UserClaim_GetAllAsync(getUserResult.Result.Get_UserID());

                    var claims = getClaimsResult.Succeeded
                                    ? getClaimsResult.Result
                                                            .Select(c => new Models.ClaimModel(c))
                                                            .ToArray()
                                    : null;

                    var detailedProfile = new Models.ApplicationDetailedUserModel()
                    {
                        UserProfile = getUserResult.Result,
                        Claims = claims
                    };

                    return new CommonWebAPI.Models.Response<Models.ApplicationDetailedUserModel>()
                    {
                        Body = detailedProfile,
                        Result = true
                    };
                }
                else
                {
                    throw this.ThrowHttpResponseWithResultException(null,
                                                    getUserResult,
                                                    HttpStatusCode.NotFound);
                }
            });
        }

        [HttpPost]
        [Route("User")]
        public async Task<CommonWebAPI.Models.Response> UpdateUser(AspNetIdentity.Identity2.BL.Models.UpdateUserModel profile)
        {
            this.ValidateArguments(profile);

            return await this.HandleResponseTask(async () =>
            {
                var findUserResult = await this.UserManager.User_FindByEmailAsync(profile.Email);

                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {
                                                                       new MessageCodeModel(InternalModels.MessagesCodesConstants.UPDATE_PROFILE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail,profile.Email))
                                                                   },
                                                                   HttpStatusCode.Forbidden);
                }
                profile.Email = this.CurrentUser.Email;
                var updateUserResult = await this.UserManager.User_UpdateAsync(profile);
                if (updateUserResult == null || !updateUserResult.Succeeded)
                {
                    throw this.ThrowHttpResponseWithResultException(
                                                new MessageCodeModel[]
                                                {
                                                new MessageCodeModel(Identity2.Resources.DefaultUpdateError)
                                                },
                                                updateUserResult,
                                                HttpStatusCode.Forbidden);
                }

                return new Response()
                {
                    Result = true
                };
            });
        }

        [HttpPost]
        [Route("User/UIFormat")]
        public async Task<CommonWebAPI.Models.Response> ChangeUserUIFormat(string UserEmail, int NewUIFormatID)
        {
            return await this.HandleResponseTask(async () =>
            {
                var findUserResult = await this.UserManager.User_FindByEmailAsync(UserEmail);

                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail,UserEmail)) },
                                                                   HttpStatusCode.Forbidden);
                }

                var updatedUser = new Identity2.BL.Models.UpdateUserModel(findUserResult.Result);
                updatedUser.UIFormatID = NewUIFormatID;

                var updateUserResult = await this.UserManager.User_UpdateAsync(updatedUser);
                if (updateUserResult == null || !updateUserResult.Succeeded)
                {
                    throw this.ThrowHttpResponseWithResultException(
                                                new MessageCodeModel[]
                                                {
                                                    new MessageCodeModel(Identity2.Resources.DefaultUpdateError)
                                                },
                                                updateUserResult,
                                                HttpStatusCode.Forbidden);
                }

                return new Response()
                {
                    Result = true
                };
            });
        }

        [HttpDelete]
        [Route("User")]
        public async Task<CommonWebAPI.Models.Response> DeleteUser(string UserEmail)
        {
            return await this.HandleResponseTask(async () =>
            {
                //reject self user
                if (string.Equals(this.CurrentUser.Email, UserEmail, StringComparison.OrdinalIgnoreCase))
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(InternalModels.MessagesCodesConstants.UPDATE_PROFILE_ERROR__INVALID_EMAIL__SELF_REJECTED, String.Format(Resources.InvalidEmail, UserEmail)) },
                                               HttpStatusCode.Forbidden);
                }

                var findUserResult = await this.UserManager.User_FindByEmailAsync(UserEmail);

                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {
                                                                       new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail,UserEmail))
                                                                   },
                                                                   HttpStatusCode.Forbidden);
                }


                var deleteResult = await this.UserManager.User_DeleteAsync(findUserResult.Result.Get_UserID(), UserEmail);

                return new Response(deleteResult.Succeeded);
            });
        }

        [HttpPost]
        [Route("User/Lockout")]
        public async Task<CommonWebAPI.Models.Response> BlockUser(string UserEmail, bool Lockout)
        {
            return await this.HandleResponseTask(async () =>
            {
                //reject self user
                if (string.Equals(this.CurrentUser.Email, UserEmail, StringComparison.OrdinalIgnoreCase))
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(InternalModels.MessagesCodesConstants.UPDATE_PROFILE_ERROR__INVALID_EMAIL__SELF_REJECTED, String.Format(Resources.InvalidEmail, UserEmail)) },
                                               HttpStatusCode.Forbidden);
                }

                var changeResult = await this.UserManager.User_ChangeLockoutUserAsync(UserEmail, Lockout);
                if (!changeResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, UserEmail)) },
                                                                   HttpStatusCode.Forbidden);
                }

                return new Response(true);
            });
        }

        [HttpPost]
        [Route("User/Password")]
        public async Task<CommonWebAPI.Models.Response> ChangeUserPassword(Models.ResetPasswordRequestModel request)
        {
            return await this.HandleResponseTask(async () =>
            {
                //validate new password (simple check)
                if (request.ConfirmPassword != request.NewPassword)
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(InternalModels.MessagesCodesConstants.RESET_PASSWORD_ERROR__PASSWORDS_MISMATCH,Identity2.Resources.PasswordMismatch) },
                                               HttpStatusCode.BadRequest);
                }

                var findUserResult = await this.UserManager.User_FindByEmailAsync(request.Email);
                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {
                                                                       new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, request.Email))
                                                                   },
                                                                   HttpStatusCode.Forbidden);
                }

                var changePasswordResult = await this.UserManager.User_ResetPasswordAsync(findUserResult.Result.Get_UserID(), request.NewPassword);

                return new Response(changePasswordResult.Succeeded);
            });
        }

        [HttpGet]
        [Route("Users/Roles")]
        public async Task<CommonWebAPI.Models.Response<Identity2.BL.Models.UserRoleModel[]>> GetValidRoles()
        {
            return await this.HandleResponseTask<Identity2.BL.Models.UserRoleModel[]>(async () =>
            {
                var findUserResult = await this.UserManager.User_FindByEmailAsync(this.CurrentUser.Email);
                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, this.CurrentUser.Email)) },
                                                                   HttpStatusCode.Forbidden);
                }

                var getUserRolesResult = await this.UserManager.UserRoles_Roles(findUserResult.Result.Get_UserID());
                var _validRoles = getUserRolesResult.Result.ToArray();

                return new Response<Identity2.BL.Models.UserRoleModel[]>()
                {
                    Body = _validRoles,
                    Result = _validRoles != null
                };
            });
        }

        [HttpGet]
        [Route("User/Roles")]
        public async Task<CommonWebAPI.Models.Response<Models.ValidUserRoleModel[]>> GetUserRoles(string UserEmail, bool FilterEnabled = false, bool FilterChecked = false)
        {
            return await this.HandleResponseTask<Models.ValidUserRoleModel[]>(async () =>
            {
                var findAdminUserResult = await this.UserManager.User_FindByEmailAsync(this.CurrentUser.Email);
                if (!findAdminUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, this.CurrentUser.Email)) },
                                                                   HttpStatusCode.Forbidden);
                }

                var findTargetUserResult = await this.UserManager.User_FindByEmailAsync(UserEmail);
                if (!findTargetUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {
                                                                       new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, UserEmail))
                                                                   },
                                                                   HttpStatusCode.Forbidden);
                }

                var getAllRoles = await this.UserManager.System_RoleModels();

                // get valid roles (admin user's roles)
                var adminUserRoles = await this.UserManager.UserRoles_Roles(findAdminUserResult.Result.Get_UserID());

                //get current roles for user (and filter to current admin user)
                var targetUserRoles = await this.UserManager.UserRoles_Roles(findTargetUserResult.Result.Get_UserID());

                //get the joined roles.
                var joinedRoles = from _systemRole in getAllRoles.Result
                                  join adminRole in adminUserRoles.Result on _systemRole.RoleID equals adminRole.RoleID into admin2system
                                  from systemRole in admin2system.DefaultIfEmpty()
                                  join _targetRole in targetUserRoles.Result on _systemRole.RoleID equals _targetRole.RoleID into target2system
                                  from targetRole in target2system.DefaultIfEmpty()
                                  select new Models.ValidUserRoleModel()
                                  {
                                      Checked = targetRole != null,
                                      Enabled = systemRole != null,
                                      RoleID = _systemRole.RoleID,
                                      RoleName = _systemRole.RoleName
                                  };

                if (FilterChecked)
                {
                    joinedRoles = joinedRoles.Where(r => r.Checked);
                }

                if (FilterEnabled)
                {
                    joinedRoles = joinedRoles.Where(r => r.Enabled);
                }

                joinedRoles = joinedRoles.Where(r => r.Enabled || r.RoleID != Identity2.BL.IdentityConstants.ROLE_PRINCIPAL__SuperAdmin);

                return new Response<Models.ValidUserRoleModel[]>()
                {
                    Body = joinedRoles.ToArray(),
                    Result = true
                };
            });
        }

        [HttpPost]
        [Route("User/Roles")]
        public async Task<CommonWebAPI.Models.Response> UpdateUserRoles(string UserEmail, Models.UpdatedUserRoleModel[] UpdatedUserRoles)
        {
            this.ValidateArguments(UpdatedUserRoles);

            return await this.HandleResponseTask(async () =>
            {
                //reject self user
                if (string.Equals(this.CurrentUser.Email, UserEmail, StringComparison.OrdinalIgnoreCase))
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(InternalModels.MessagesCodesConstants.UPDATE_PROFILE_ERROR__INVALID_EMAIL__SELF_REJECTED, String.Format(Resources.InvalidEmail, UserEmail)) },
                                               HttpStatusCode.Forbidden);
                }

                var findAdminUserResult = await this.UserManager.User_FindByEmailAsync(this.CurrentUser.Email);
                if (!findAdminUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, this.CurrentUser.Email)) },
                                                                   HttpStatusCode.Forbidden);
                }

                var findTargetUserResult = await this.UserManager.User_FindByEmailAsync(UserEmail);
                if (!findTargetUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.ADMIN_UPDATE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail, UserEmail)) },
                                                                   HttpStatusCode.Forbidden);
                }

                // get valid roles (admin user's roles)
                var adminUserRoles = await this.UserManager.UserRoles_Roles(findAdminUserResult.Result.Get_UserID());

                //get current roles for user (and filter to current admin user)
                var targetUserRoles = await this.UserManager.UserRoles_Roles(findTargetUserResult.Result.Get_UserID());

                //get the joined roles.
                var joinedRoles = from adminRole in adminUserRoles.Result
                                  join _updateRole in UpdatedUserRoles on adminRole.RoleID equals _updateRole.RoleID into update2system
                                  from updateRole in update2system.DefaultIfEmpty()
                                  join _targetRole in targetUserRoles.Result on adminRole.RoleID equals _targetRole.RoleID into target2system
                                  from targetRole in target2system.DefaultIfEmpty()
                                  select new Identity2.BL.Models.UpdatedUserRoleModel()
                                  {
                                      RoleID = adminRole.RoleID,
                                      Remove = targetRole != null && (updateRole == null || !updateRole.Checked),
                                      Add = targetRole == null && updateRole != null && updateRole.Checked && adminRole != null
                                  };

                var updateRolesResult = await this.UserManager.UserRoles_UpdateAsync(findTargetUserResult.Result.Get_UserID(), joinedRoles);


                return new Response(updateRolesResult.Succeeded);
            });
        }
    }
}
