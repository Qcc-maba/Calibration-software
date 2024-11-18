using System;
using Microsoft.Owin.Security;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Web.Http;
using Newtonsoft.Json.Linq;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using Maba.AccountSystem.AspNetIdentity.Identity2;
using System.Web;
using System.Text;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using Maba.Connectors.JsonHelpersLibrary;
using Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models;

namespace Maba.AccountSystem.WebServices.Contollers
{
    [RoutePrefix("Login")]
    public class LoginController : BaseController
    {
        #region members (+ static)

        private static System.Collections.Concurrent.ConcurrentDictionary<string, DateTime> _FailedTemplates = new System.Collections.Concurrent.ConcurrentDictionary<string, DateTime>();

        #endregion

        #region private methods

        internal static string GenerateAccessToken(AccessTokenHelper CurrentTokenHelper, Identity2.BL.Models.ApplicationUserModel User, string LoginProvider = null, params Claim[] Claims)
        {
            LoginProvider = LoginProvider == null
                ? $"{Identity2.Common.AccessTokenHelper.AUTHENTICATION_TYPE_LOCAL}_{LoginProvider}"
                : AccessTokenHelper.AUTHENTICATION_TYPE_LOCAL;

            var userData = new Identity2.Common.UserData()
            {
                UserGUID = User.UserGuid,
                UserID = User.Get_UserID(),
                UserName = User.Get_UserName(),
                LoginProvider = LoginProvider,
                Email = User.Email,
                GivenName = User.FirstName,
                Surename = User.LastName
            };

            var ticket = AccessTokenHelper.CreateUserTicket(userData, Claims);

            //add claims
            var _SecurityStamp = User.Get_SecurityStamp();
            if (!String.IsNullOrEmpty(_SecurityStamp))
            {
                ticket.Identity.AddClaim(new Claim(ClaimTypes.Hash, _SecurityStamp));
            }

            ticket.Identity.SetUserTemperatureUnit(User.Temperature_UnitView);
            ticket.Identity.SetUserCultureCode(User.CultureCode);

            var access_token = CurrentTokenHelper.Protect(ticket);
            return access_token;
        }

        internal async static Task<CommonWebAPI.Models.Response<Models.LoginResponseModel>> ProccessLogin(Settings.WebServicesSettings carrier, long UserID, ApplicationUserModel UserObject = null)
        {
            //create manager
            var userManager = carrier.Generator_UserManager();

            //get user, if none
            if (UserObject == null)
            {
                var findUserResult = await userManager.User_FindByIDAsync(UserID);
                if (!findUserResult.Succeeded)
                {
                    return new Hydra2.Systems.Common.CommonWebAPI.Models.Response<Models.LoginResponseModel>()
                    {
                        Result = false
                    };
                }

                UserObject = findUserResult.Result;
            }
            {
                UserID = UserObject.Get_UserID();
            }

            //create token
            var accessTokenHelper = AccessTokenHelper.CreateAccessTokenHelper(
                                                                        carrier.DataProtectionOptions.CreateDataProtectionProvider(),
                                                                        carrier.DataProtectionOptions.Purposes);

            //look for login providers
            var logins = await userManager.UserLogin_GetAllAsync(UserID);
            var loginProvider = logins != null && logins.Result.Length > 0
                                                                            ? logins.Result[0].LoginProvider
                                                                            : null;


            //get user's PRINCIPAL roles
            //useful for services allowed for admins only (example)
            var getRolesResult = await userManager.UserRoles_Roles(UserObject.Get_UserID(), Identity2.BL.IdentityConstants.ROLE_PRINCIPAL__GROUP_ID);
            Claim[] _Claims = null;
            if (getRolesResult.Succeeded)
            {
                _Claims = getRolesResult.Result
                                        .Select(r => new Claim(ClaimsIdentity.DefaultRoleClaimType, r.RoleID.ToString()))
                                        .ToArray();
            }


            //build and return response
            var response = new Hydra2.Systems.Common.CommonWebAPI.Models.Response<Models.LoginResponseModel>()
            {
                Result = true,
                Body = new Models.LoginResponseModel()
                {
                    AccountToken = GenerateAccessToken(accessTokenHelper, UserObject, loginProvider, _Claims)
                }
            };

            return response;
        }
        private async Task<CommonWebAPI.Models.Response<string>> SendEmailConfirmEmailAsync(Identity2.BL.Models.ApplicationUserModel user, Uri confirmPageUrl)
        {
            var generateTokenResult = await UserManager.User_GenerateEmailConfirmationTokenAsync(user.Get_UserID());
            if (!generateTokenResult.Succeeded)
            {
                return new Hydra2.Systems.Common.CommonWebAPI.Models.Response<string>()
                {
                    Result = false
                };
            }

            #region build conform page url

            var uri = new UriBuilder(confirmPageUrl);
            var query = confirmPageUrl.ParseQueryString();
            query["AccessToken"] = generateTokenResult.Result;
            query["email"] = user.Email;
            uri.Query = query.ToString();

            #endregion

            #region prepare data for xslt transforming

            var data = new InternalModels.EmailConfirmTransformData()
            {
                Email = user.Email,
                FirstName = user.FirstName,
                LastName = user.LastName,
                Link = uri.ToString(),
                UserObject = user
            };

            #endregion

            #region prepare SMTP message

            var message = new Connectors.EmailServices.EmailMessage()
            {
                To = user.Email,
                Subject = "Confirm Your Email",
                To_DisplayName = $"{user.FirstName}, {user.LastName}",
            };

            #endregion

            #region look for valid template (based on user's culture)

            bool localCopyUsed = false;
            var cultureOptions = new string[] { user.CultureCode, null };
            string templateUri = null;
            string selectedCulture = null;

            DateTime d;

            for (int cultureIndex = 0; cultureIndex < cultureOptions.Length; cultureIndex++)
            {
                selectedCulture = cultureOptions[cultureIndex];
                templateUri = String.Format($"{this.Carrier.ResourceLinksSettings.TemplateFiles}/{this.Carrier.ResourceLinksSettings.TemplateFile_ConfirmEmail}", selectedCulture == null ? null : $"_{selectedCulture}");

                if (_FailedTemplates.TryGetValue(templateUri, out d))
                {
                    //if failed, keep this failure as cache.
                    if (DateTime.UtcNow < d)
                    {
                        continue;
                    }
                }

                try
                {
                    var request = System.Net.HttpWebRequest.Create(templateUri);
                    request.Method = "HEAD";
                    var response = await request.GetResponseAsync();
                    var httpResponse = response as HttpWebResponse;
                    if (HttpStatusCode.OK <= httpResponse.StatusCode && httpResponse.StatusCode <= HttpStatusCode.NoContent && response.ContentLength > 0)
                    {
                        break;
                    }
                }
                catch
                {
                    _FailedTemplates[templateUri] = DateTime.UtcNow;
                }

                templateUri = null;
                selectedCulture = null;
            }

            if (templateUri == null)
            {
                //try locally
                templateUri = System.Web.Hosting.HostingEnvironment.MapPath("~");
                templateUri = System.IO.Path.Combine(templateUri, "Assets", "Templates", String.Format(this.Carrier.ResourceLinksSettings.TemplateFile_ConfirmEmail, ""));

                if (!System.IO.File.Exists(templateUri))
                {
                    return new Hydra2.Systems.Common.CommonWebAPI.Models.Response<string>()
                    {
                        Result = false,
                        Messages = new Hydra2.Systems.Common.CommonWebAPI.Models.MessageCodeModel[]
                                    { new Hydra2.Systems.Common.CommonWebAPI.Models.MessageCodeModel(1, "Sending [Confirm-Email] was failed.")},
                    };
                }

                localCopyUsed = true;
            }

            #endregion

            var xsltTransformer = new Connectors.EmailServices.MailTemplateTranformers.XsltMailTemplateTranformer();
            message.Body = await xsltTransformer.Transform(
                                        "ConfirmEmail",
                                        templateUri,
                                        data,
                                        //parameters
                                        null
                                        );

            //send the message by SMTP
            bool sendResult = false;
            using (var emailService = this.Carrier.GetEmailService())
            {
                sendResult = await emailService.SendAsync(message);
            }

            return new Hydra2.Systems.Common.CommonWebAPI.Models.Response<string>()
            {
                Result = sendResult,
                Body = generateTokenResult.Result,
                Messages = new CommonWebAPI.Models.MessageCodeModel[]
                 {
                     new CommonWebAPI.Models.MessageCodeModel(0, "Template Source " + (localCopyUsed ? "[LOCAL]" : "[REMOTE]")) }
            };
        }

        #endregion

        #region [Authorize]

        [Route("Unregister")]
        [HttpDelete]
        [Authorize]
        public async Task<CommonWebAPI.Models.Response> UnRegister()
        {
            var identity = this.User.Identity as ClaimsIdentity;
            var identityEmail = identity.GetEmail();

            return await this.HandleResponseTask(async () =>
            {
                #region  validate mail

                if (identityEmail != this.CurrentUser.Email)
                {
                    throw this.ThrowHttpResponseException(
                                            new CommonWebAPI.Models.MessageCodeModel[]
                                            {
                                                                new CommonWebAPI.Models.MessageCodeModel(1,String.Format(Resources.InvalidEmail,identityEmail))
                                            },
                                            HttpStatusCode.Forbidden);
                }

                #endregion

                var currenUserResult = await UserManager.User_FindByEmailAsync(identityEmail);
                if (!currenUserResult.Succeeded || currenUserResult.Result == null)
                {
                    throw this.ThrowHttpResponseWithResultException(
                                            new CommonWebAPI.Models.MessageCodeModel[]
                                            {
                                                                new CommonWebAPI.Models.MessageCodeModel(1,String.Format(Resources.InvalidEmail,identityEmail)),
                                                                new CommonWebAPI.Models.MessageCodeModel(2,String.Format(Resources.UserNameNotFound,CurrentUser.UserName))
                                            },
                                            currenUserResult,
                                            HttpStatusCode.Forbidden);
                }

                var addResult = await UserManager.User_DeleteAsync(currenUserResult.Result.Get_UserID(), currenUserResult.Result.Email);

                var messages = new CommonWebAPI.Models.MessageCodeModel[]
                    {
                    new Hydra2.Systems.Common.CommonWebAPI.Models.MessageCodeModel(0,"User {0} un-registered successfully!", identityEmail)
                    }
                    .Concat(addResult.Errors
                                        .Select(r => new CommonWebAPI.Models.MessageCodeModel(0, r)))
                    .ToArray();


                return new CommonWebAPI.Models.Response()
                {
                    Result = addResult.Succeeded,
                    Messages = messages
                };
            });
        }

        #endregion

        #region [AllowAnonymous] Login / Register

        [AllowAnonymous]
        [Route("Register")]
        [HttpPost]
        public async Task<CommonWebAPI.Models.Response<Models.RegisterResponseModel>> Register(Models.RegisterRequestModel registerModel)
        {
            this.ValidateArguments(registerModel);

            return await this.HandleResponseTask(async () =>
            {
                var identity = this.User.Identity as ClaimsIdentity;

                if (identity.IsAuthenticated && this.Request.GetOwinContext().Authentication.GetExternalAuthenticationTypes().Any(e => e.AuthenticationType == identity.AuthenticationType))
                {
                    //THIS CODE WAS NEVER TESTED !!!
                    //It uses the original external-provider identity.
                    //It can be used only if after login by external provider - redirect the customer to register page.
                    //since the system uses only it's own token, not the external provider token.
                    //IT CANNOT BE USED - MUST BE CHANGED BEFORE CAN WORK 
                    #region External login register

                    var externalUserEmail = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Email).Value;
                    var externalLoginregisterResponse = new CommonWebAPI.Models.Response<Models.RegisterResponseModel>()
                    {
                        Body = new Models.RegisterResponseModel()
                    };


                    //verify UserName/Email is free
                    var existsUser = await UserManager.User_FindByEmailAsync(externalUserEmail);
                    if (existsUser != null && existsUser.Result != null && existsUser.Result.Email == externalUserEmail)
                    {
                        throw this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                                        {new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__USER_ALREADY_EXISTS,"User already exists !") }, HttpStatusCode.Conflict);
                    }




                    var externalProviderInfo = OWINLibrary.Security.Externals.ExternalLoginData.FromIdentity(identity);

                    var externalUser = new Identity2.BL.Models.CreateUserModel();
                    externalUser.PhoneNumber = registerModel.Phone;
                    externalUser.PhoneConfirmed = false;

                    externalUser.Email = externalUserEmail;
                    externalUser.EmailConfirmed = true;

                    var addResult = await UserManager.User_CreateAsync(externalUser, true);
                    if (!addResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(1,"Failed to create external user")
                                                                },
                                                                addResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    var userBack = await UserManager.User_FindByEmailAsync(registerModel.Email);
                    if (!userBack.Succeeded || String.IsNullOrEmpty(userBack.Result.UserGuid))
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(11,"Failed to create external user")
                                                                },
                                                                addResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    var newExternalUser = userBack.Result;
                    var addLoginResult = await UserManager.UserLogin_AddAsync(newExternalUser.Get_UserID(), new Identity2.BL.Models.UserLoginInfoModel(externalProviderInfo.LoginProvider, externalProviderInfo.ProviderKey));
                    if (!addLoginResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(2, "Failed to add external login user {0}", externalProviderInfo.LoginProvider)
                                                                },
                                                                addLoginResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    #region add phone

                    if (!String.IsNullOrEmpty(registerModel.Phone))
                    {
                        if (!String.IsNullOrEmpty(registerModel.PhoneVerificationCode))
                        {
                            var verifyPhoneResult = await UserManager.User_ChangePhoneNumberAsync(newExternalUser.Get_UserID(), registerModel.Phone, registerModel.PhoneVerificationCode);
                            if (!verifyPhoneResult.Succeeded)
                            {
                                externalLoginregisterResponse.AddMessages(new CommonWebAPI.Models.MessageCodeModel(3, "Failed to verify phone"));
                            }
                        }
                    }

                    #endregion

                    #region add claims

                    var newClaims = new List<Identity2.BL.Models.UserClaimModel>();
                    newClaims.Add(new Identity2.BL.Models.UserClaimModel(ClaimTypes.Surname, registerModel.LastName));
                    newClaims.Add(new Identity2.BL.Models.UserClaimModel(ClaimTypes.GivenName, registerModel.FirstName));

                    if (identity.AuthenticationType == "Google")
                    {
                        var profileClaim = identity.Claims.FirstOrDefault(c => c.Type.EndsWith("profile"));
                        if (profileClaim != null)
                        {
                            newClaims.Add(new Identity2.BL.Models.UserClaimModel("Profile", profileClaim.Value));
                        }
                    }

                    var addfClaimsResult = await UserManager.UserClaim_AddAsync(newExternalUser.Get_UserID(), newClaims);
                    if (!addfClaimsResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(2, "Failed to add claims")
                                                                },
                                                                addfClaimsResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    #endregion

                    externalLoginregisterResponse.Body.ShortenToken = null; //no need for token. access_token.Substring(0, 10);
                    externalLoginregisterResponse.Result = true;

                    return externalLoginregisterResponse;

                    #endregion
                }
                else
                {
                    #region "Regular" Local New User

                    var finalResponse = new CommonWebAPI.Models.Response<Models.RegisterResponseModel>()
                    {
                        Body = new Models.RegisterResponseModel()
                    };

                    #region  verify UserName/Email is free
                    var existsUser = await UserManager.User_FindByEmailAsync(registerModel.Email);
                    if (existsUser != null && existsUser.Result != null && existsUser.Result.Email == registerModel.Email)
                    {
                        throw this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                                        {new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__USER_ALREADY_EXISTS,"User already exists !") }, HttpStatusCode.Conflict);
                    }

                    #endregion

                    #region verify passwords (other advanced verification of passwords are done in manager_User_CreateAsync..
                    if (String.IsNullOrEmpty(registerModel.Password)
                        || String.IsNullOrEmpty(registerModel.ConfirmPassword)
                        || registerModel.Password != registerModel.ConfirmPassword)
                    {
                        throw this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                    {new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__USER_ALREADY_EXISTS,Identity2.Resources.PasswordMismatch) }, HttpStatusCode.BadRequest);
                    }

                    #endregion

                    #region Create the user in store

                    var localUser = new Identity2.BL.Models.CreateUserModel();
                    localUser.Email = registerModel.Email;
                    localUser.FirstName = registerModel.FirstName;
                    localUser.LastName = registerModel.LastName;
                    localUser.EmailConfirmed = false;
                    localUser.PhoneNumber = registerModel.Phone;
                    localUser.PhoneConfirmed = false;

                    ///////////make sure to have the ID
                    var addResult = await UserManager.User_CreateAsync(localUser, true, registerModel.Password);
                    if (!addResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__ERROR_CREATE_USER_1, "Failed to create user")
                                                                },
                                                                addResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    var findAgainUserResult = await UserManager.User_FindByEmailAsync(localUser.Email);
                    if (!findAgainUserResult.ValidateSuccess() || String.IsNullOrEmpty(findAgainUserResult.Result.UserGuid))
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__ERROR_CREATE_USER_2, "Failed to find just-created user")
                                                                },
                                                                findAgainUserResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    #endregion

                    #region add phone

                    if (!String.IsNullOrEmpty(registerModel.Phone))
                    {
                        if (!String.IsNullOrEmpty(registerModel.PhoneVerificationCode))
                        {
                            var verifyPhoneResult = await UserManager.User_ChangePhoneNumberAsync(findAgainUserResult.Result.Get_UserID(), registerModel.Phone, registerModel.PhoneVerificationCode);
                            if (verifyPhoneResult.Succeeded)
                            {
                                finalResponse.AddMessages(new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__USER_PHONE_VERIFICATION_ERROR, "Failed to verify phone"));
                            }
                        }
                    }

                    #endregion

                    #region add claims

                    var newClaims = new List<Identity2.BL.Models.UserClaimModel>();
                    newClaims.Add(new Identity2.BL.Models.UserClaimModel(ClaimTypes.Surname, registerModel.LastName));
                    newClaims.Add(new Identity2.BL.Models.UserClaimModel(ClaimTypes.GivenName, registerModel.FirstName));

                    var addfClaimsResult = await UserManager.UserClaim_AddAsync(findAgainUserResult.Result.Get_UserID(), newClaims);
                    if (!addfClaimsResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new CommonWebAPI.Models.MessageCodeModel[]
                                                                {
                                                                new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.REGISTER_ERROR__ERROR_CREATE_USER_CLAIMS, "Failed to add claims")
                                                                },
                                                                addfClaimsResult,
                                                                HttpStatusCode.InternalServerError);
                    }

                    #endregion

                    #region send Welcome SMS (when phoneNumber is provided)

                    if (!String.IsNullOrEmpty(registerModel.Phone))
                    {
                        var smsService = this.Carrier.GetSMSService();
                        if (smsService != null)
                        {
                            var message = new Connectors.SMSServices.SMSMessage()
                            {
                                Body = "Thank you for registering Maba-Smart. Visit your device(s) on https://online.Maba-smart.com",
                                Destination = registerModel.Phone
                            };
                            finalResponse.Body.SMSSent = await smsService.SendAsync(message);
                        }
                    }

                    #endregion

                    #region create confirmation email

                    //first priority for URL in request model (POST json body)
                    //second, take the referrer
                    var confirmEmailPageUrl = String.IsNullOrEmpty(registerModel.ConfirmEmailPageUrl)
                                                                                                    ? this.Request.Headers.Referrer
                                                                                                    : new Uri(registerModel.ConfirmEmailPageUrl);

                    var sendEmailResult = await SendEmailConfirmEmailAsync(findAgainUserResult.Result, confirmEmailPageUrl);
                    finalResponse.AddMessages(sendEmailResult.Messages);

                    if (sendEmailResult.Result)
                    {
                        finalResponse.Result = true;
                        finalResponse.Body.ShortenToken = sendEmailResult.Body.Substring(0, 5);
                    }
                    else
                    {
                        finalResponse.Result = false;
                    }

                    #endregion

                    return finalResponse;

                    #endregion
                }
            });
        }

        [AllowAnonymous]
        [Route("ConfirmEmail")]
        [HttpPost]
        public async Task<CommonWebAPI.Models.Response> ConfirmEmailToken(Models.ConfirmEmailModel confirm)
        {
            this.ValidateArguments(confirm);

            return await this.HandleResponseTask(async () =>
            {
                Identity2.ActionResult result = await UserManager.User_ConfirmEmailAsync(confirm.Email, confirm.ConfirmEmailToken);

                if (result.Succeeded)
                {
                    return new CommonWebAPI.Models.Response()
                    {
                        Result = true
                    };
                }
                else
                {
                    throw this.ThrowHttpResponseWithResultException(
                                                           new CommonWebAPI.Models.MessageCodeModel[]
                                                           {
                                                           new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.CONFIRMEMAIL_ERROR__FAILED_EMAIL_CONFIRMATION,"Failed to confirm email")
                                                           },
                                                           result,
                                                           HttpStatusCode.BadRequest);
                }
            });
        }

        [AllowAnonymous]
        [Route("LocalLogin")]
        [HttpPost]
        public async Task<CommonWebAPI.Models.Response<Models.LoginResponseModel>> LocalLogin(Models.LoginRequestModel loginModel)
        {
            this.ValidateArguments(loginModel);

            return await this.HandleResponseTask<Models.LoginResponseModel>(async () =>
            {
                var findUserResult = await UserManager.User_FindByEmailAsync(loginModel.Email, loginModel.Password);

                if (findUserResult == null || !findUserResult.Succeeded)
                {
                    var messages = new CommonWebAPI.Models.MessageCodeModel[2];
                    messages[0] = new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.LOGIN_ERROR__ERROR_INVALID_EMAIL, String.Format(Resources.InvalidEmail, loginModel.Email));
                    messages[1] = new CommonWebAPI.Models.MessageCodeModel(InternalModels.MessagesCodesConstants.LOGIN_ERROR__ERROR_MISMATCH_PASSWORDS, String.Format(Resources.PasswordMismatch, loginModel.Email));

                    throw this.ThrowHttpResponseWithResultException(
                                                               messages
                                                                   .Where(m => m != null)
                                                                   .ToArray(),
                                                               findUserResult,
                                                               HttpStatusCode.Forbidden);
                }
                else
                {

                    var response = await ProccessLogin(this.Carrier, findUserResult.Result.Get_UserID(), findUserResult.Result);

                    return response;
                }
            });
        }        

        #endregion

        #region [AllowAnonymous] - ExternalLogin (Facebook, Google,..)

        [AllowAnonymous]
        [Route("ExternalLogin")]
        [HttpGet]
        public IHttpActionResult ExternalLogin(string provider, string returnUrl)
        {
            if (String.IsNullOrEmpty(returnUrl))
            {
                returnUrl = this.Request.Headers.Referrer == null ? null : this.Request.Headers.Referrer.ToString();
            }
            if (String.IsNullOrEmpty(returnUrl))
            {
                return BadRequest("No returnUrl was found.");
            }

            //validate this provider is supported.
            if (!this.Request.GetOwinContext().Authentication.GetExternalAuthenticationTypes().Any(e => e.AuthenticationType == provider))
            {
                //Error - Invalid External Provider
                return BadRequest(String.Format("Invalid External Provider {0}.", provider));
            }

            return new HttpActionResults.ChallengeResult(provider, this, returnUrl);
        }

        #endregion
    }
}
