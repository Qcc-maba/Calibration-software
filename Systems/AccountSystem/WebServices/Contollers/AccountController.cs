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
using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using Models = Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models;
using Maba.Connectors.JsonHelpersLibrary;
using Maba.AccountSystem.AspNetIdentity.Identity2;
using System.Web;
using System.Text;
using System.IO;
using System.Net.Http.Headers;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Models;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using System.Collections;

namespace Maba.AccountSystem.WebServices.Contollers
{
    [RoutePrefix("Account")]
    [Authorize]
    public class AccountController : BaseController
    {
        #region CONSTANTS

        private const string MIME_IMGAE_PREFIX = "image/";

        //Systems
        //private const string SYSTEM_MF = "System_MF";
        //private const string SYSTEM_XCI_ADMIN = "System_XCI-Admin";
        //private const string SYSTEM_Hydra2_ADMIN = "System_Hydra2-Admin";
        //private const string SYSTEM_ACCOUNT_ADMIN = "System_Account";

        #endregion

        #region ctor(s)

        public AccountController()
        {
        }

        #endregion

        #region members (+ static)

        private static System.Collections.Concurrent.ConcurrentDictionary<string, DateTime> _FailedTemplates = new System.Collections.Concurrent.ConcurrentDictionary<string, DateTime>();

        #endregion

        #region private methods

        private async Task<CommonWebAPI.Models.Response<string>> SendEmail_ResetPasswordEmailAsync(Identity2.BL.Models.ApplicationUserModel user, Uri resetPasswordPageUrl)
        {
            var generateTokenResult = await UserManager.User_GeneratePasswordResetTokenAsync(user.Get_UserID());
            if (!generateTokenResult.Succeeded)
            {
                return new Hydra2.Systems.Common.CommonWebAPI.Models.Response<string>()
                {
                    Result = false
                };
            }

            #region build conform page url

            var uri = new UriBuilder(resetPasswordPageUrl);
            var query = resetPasswordPageUrl.ParseQueryString();
            query["ResetToken"] = generateTokenResult.Result;
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
                Subject = "Reset Your Password",
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
                templateUri = String.Format($"{this.Carrier.ResourceLinksSettings.TemplateFiles}/{this.Carrier.ResourceLinksSettings.TemplateFile_ResetPassword}", selectedCulture == null ? null : $"_{selectedCulture}");

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
                templateUri = System.IO.Path.Combine(templateUri, "Assets", "Templates", String.Format(this.Carrier.ResourceLinksSettings.TemplateFile_ResetPassword, ""));

                if (!System.IO.File.Exists(templateUri))
                {
                    return new Hydra2.Systems.Common.CommonWebAPI.Models.Response<string>()
                    {
                        Result = false,
                        Messages = new Hydra2.Systems.Common.CommonWebAPI.Models.MessageCodeModel[]
                                    { new Hydra2.Systems.Common.CommonWebAPI.Models.MessageCodeModel(1, "Sending [Reset-Password] was failed.")},
                    };
                }

                localCopyUsed = true;
            }

            #endregion

            var xsltTransformer = new Connectors.EmailServices.MailTemplateTranformers.XsltMailTemplateTranformer();
            message.Body = await xsltTransformer.Transform(
                                        "ResetPassword",
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

        #region [AllowAnonymous] Actions

        [AllowAnonymous]
        [Route("GetCookie")]
        [HttpGet]
        public HttpResponseMessage GetCookie(string callback)
        {
            var jToken = new Newtonsoft.Json.Linq.JObject();
            var resp = new HttpResponseMessage()
            {
                StatusCode = HttpStatusCode.OK
            };

            var allCookies = this.Request.Headers.GetCookies();

            if (allCookies == null || allCookies.Count == 0 || allCookies[0].Cookies.Count == 0)
            {
                jToken.Add(new JProperty("success", "false"));
            }
            else
            {

                var allCookies_arr = allCookies[0].Cookies
                                                    .Select(c => c.Name + ":" + c.Value)
                                                    .ToArray();

                jToken.Add(new JProperty("success", "true"));
                var tokens = new JObject();
                var keys = new List<string>();
                foreach (var c in allCookies[0].Cookies)
                {
                    if (keys.Contains(c.Name))
                        continue;

                    keys.Add(c.Name);
                    tokens.Add(new JProperty(c.Name, c.Value));
                }
                jToken.Add("tokens", tokens);
            }

            resp.Content = new StringContent(String.Format("{0}({1});",
                                                        callback, jToken.ToString()), Encoding.UTF8, "text/plain");
            return resp;
        }

        [AllowAnonymous]
        [Route("ForgotPassword")]
        [HttpPost]
        public async Task<Response<Models.ForgotPasswordResponseModel>> ForgotPasswordRequest(Models.ForgotPasswordRequestModel request)
        {
            this.ValidateArguments(request);

            return await this.HandleResponseTask<Models.ForgotPasswordResponseModel>(async () =>
            {
                var findUserResult = await UserManager.User_FindByEmailAsync(request.Email);

                if (!findUserResult.ValidateSuccess())
                {
                    return new Response<Models.ForgotPasswordResponseModel>()
                    {
                        Result = false
                    };
                }
                else
                {
                    var user = findUserResult.Result;

                    //first priority for URL in request model (POST JSON body)
                    //second, take the referrer
                    var resetPasswordPageUrl = String.IsNullOrEmpty(request.ResetPasswordPageUrl)
                                                                                                    ? this.Request.Headers.Referrer
                                                                                                    : new Uri(request.ResetPasswordPageUrl);

                    var sentResetPasswordResult = await SendEmail_ResetPasswordEmailAsync(user, resetPasswordPageUrl);

                    return new Response<Models.ForgotPasswordResponseModel>()
                    {
                        Body = new Models.ForgotPasswordResponseModel()
                        {
                            SentEmail = request.Email,
                            ShortenToken = sentResetPasswordResult.Body.Substring(0, 5)
                        },
                        Result = true
                    };
                }
            });
        }

        [AllowAnonymous]
        [Route("ResetPassword")]
        [HttpPost]
        public async Task<Response> ResetPasswordRequest(Models.ResetPasswordRequestModel request)
        {
            this.ValidateArguments(request);

            return await this.HandleResponseTask(async () =>
            {
                //verify passwords (other advanced verification of passwords are done in manager_User_CreateAsync..
                if (!String.IsNullOrEmpty(request.ResetPasswordToken)
                     && !String.IsNullOrEmpty(request.NewPassword))
                {
                    #region make reset with token

                    var existsUser = await UserManager.User_FindByEmailAsync(request.Email);
                    if (!existsUser.Succeeded)
                    {
                        throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                  {
                                                  new MessageCodeModel(InternalModels.MessagesCodesConstants.RESET_PASSWORD_ERROR__INVALID_EMAIL,String.Format(Identity2.Resources.InvalidEmail, request.Email)),
                                                  new MessageCodeModel(InternalModels.MessagesCodesConstants.RESET_PASSWORD_ERROR__INVALID_TOKEN,Identity2.Resources.InvalidToken),
                                                  },
                                                  HttpStatusCode.BadRequest);
                    }

                    var restPasswordResult = await UserManager.User_ResetPasswordAsync(existsUser.Result.Get_UserID(), request.ResetPasswordToken, request.NewPassword);
                    if (!restPasswordResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(new MessageCodeModel[] { new MessageCodeModel(1, "Failed to reset Password") },
                                                                restPasswordResult,
                                                                HttpStatusCode.Forbidden);
                    }
                    return new Response()
                    {
                        Result = true
                    };

                    #endregion
                }
                else if (!String.IsNullOrEmpty(request.OldPassword)
                    && !String.IsNullOrEmpty(request.NewPassword))
                {
                    #region reset password using the old password

                    this.IsSignedIn();

                    //validate new password (simple check)
                    if (request.ConfirmPassword != request.NewPassword)
                    {
                        throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                   {new MessageCodeModel(InternalModels.MessagesCodesConstants.RESET_PASSWORD_ERROR__PASSWORDS_MISMATCH,Identity2.Resources.PasswordMismatch) },
                                                   HttpStatusCode.BadRequest);
                    }

                    var findUserResult = await UserManager.User_FindByEmailAsync(this.CurrentUser.Email);
                    if (!findUserResult.ValidateSuccess())
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new MessageCodeModel[]
                                                                      {
                                                                      new MessageCodeModel(2, String.Format(Resources.InvalidEmail,this.CurrentUser.Email)),
                                                                      },
                                                                      findUserResult,
                                                                      HttpStatusCode.BadRequest);
                    }

                    //change password
                    var checkPasswordResult = await UserManager.User_ChangePasswordAsync(findUserResult.Result.Get_UserID(), request.OldPassword, request.NewPassword);
                    if (!checkPasswordResult.Succeeded)
                    {
                        throw this.ThrowHttpResponseWithResultException(
                                                                new MessageCodeModel[] {
                                                            new MessageCodeModel(3,"Reset/"+Resources.PasswordMismatch)
                                                                },
                                                                checkPasswordResult,
                                                                HttpStatusCode.BadRequest);
                    }

                    return new Response()
                    {
                        Result = true
                    };

                    #endregion
                }

                throw this.ThrowHttpResponseException(null, HttpStatusCode.BadRequest);
            });
        }

        [HttpGet]
        [HttpPost]
        [Route("Test")]
        [AllowAnonymous]
        public async Task<HttpResponseMessage> Test()
        {
            var jToken = new Newtonsoft.Json.Linq.JObject();

            //properties
            jToken.Add(new JProperty("Url", this.Request.RequestUri.ToString()));
            jToken.Add(new JProperty("Referrer", this.Request.Headers.Referrer));
            jToken.Add(new JProperty("IsLocal", this.Request.IsLocal()));
            jToken.Add(new JProperty("IsLoopback", this.Request.RequestUri.IsLoopback));
            jToken.Add(new JProperty("UserHostAddress", HttpContext.Current.Request.UserHostAddress));
            jToken.Add(new JProperty("UserHostName", HttpContext.Current.Request.UserHostName));
            jToken.Add(new JProperty("UserLanguages", HttpContext.Current.Request.UserLanguages));
            jToken.Add(new JProperty("HttpMethod", HttpContext.Current.Request.HttpMethod));

            #region current user

            var identity = this.User.Identity as ClaimsIdentity;

            var userToken = new Newtonsoft.Json.Linq.JObject();
            userToken.Add(new JProperty("IsAuthenticated", identity.IsAuthenticated));

            jToken.Add(new JProperty("currentUser", userToken));
            if (identity.IsAuthenticated)
            {
                var existsUser = await UserManager.User_FindByEmailAsync(this.CurrentUser.Email);
                if (existsUser.Succeeded)
                {
                    userToken.Add(new JProperty("EmailConfirmed", existsUser.Result.EmailConfirmed));

                    #region general info

                    var infoToken = new Newtonsoft.Json.Linq.JObject();
                    userToken.Add(new JProperty("generalInfo", infoToken));

                    //Temperature
                    infoToken.Add(new JProperty("Temperature", new JObject(
                                                                        new JProperty("unitID", existsUser.Result.TemperatureUnitID),
                                                                        new JProperty("displayName", existsUser.Result.Temperature_DisplayName),
                                                                        new JProperty("unitView", existsUser.Result.Temperature_UnitView))));

                    //TimeZone
                    infoToken.Add(new JProperty("TimeZone", new JObject(
                                                                        new JProperty("timeZoneID", existsUser.Result.TimeZoneID),
                                                                        new JProperty("actualOffset", existsUser.Result.Get_ActualOffset()))));

                    //UIFormat
                    infoToken.Add(new JProperty("UIFormat", new JObject(
                                                                        new JProperty("timeZoneID", existsUser.Result.UIFormatID),
                                                                        new JProperty("cultureCode", existsUser.Result.CultureCode))));
                    #endregion

                    #region  logins
                    var logins = await UserManager.UserLogin_GetAllAsync(existsUser.Result.Get_UserID());
                    var loginsToken = new Newtonsoft.Json.Linq.JArray();
                    userToken.Add(new JProperty("logins", loginsToken));
                    foreach (var l in logins.Result)
                    {
                        loginsToken.Add(new JObject(new JProperty("Provider", l.LoginProvider), new JProperty("Key", l.ProviderKey)));
                    }

                    #endregion

                    #region roles

                    var roles = await UserManager.UserRoles_Roles(existsUser.Result.Get_UserID());
                    var rolesToken = new Newtonsoft.Json.Linq.JArray();
                    userToken.Add(new JProperty("roles", rolesToken));

                    foreach (var r in roles.Result)
                    {
                        rolesToken.Add(new JObject(new JProperty("roleID", r.RoleID), new JProperty("roleName", r.RoleName)));
                    }

                    #endregion
                }

                #region identity

                var identityToken = new JObject();
                userToken.Add(new JProperty("identity", identityToken));
                identityToken.Add(new JProperty("AuthenticationType", identity.AuthenticationType));
                var claimsToken = new JArray(identity.Claims
                                                        .Select(c => new JObject(
                                                                                new JProperty("type", c.Type),
                                                                                new JProperty("Value", c.Value)))
                                                        .ToArray());
                identityToken.Add(new JProperty("Claims", claimsToken));

                #endregion
            }

            #endregion

            //params
            var urlParams = new JObject();
            foreach (var p in this.Request.GetQueryNameValuePairs())
            {
                urlParams.Add(new JProperty(p.Key, p.Value));
            }
            jToken.Add(new JProperty("urlParams", urlParams));

            //headers
            var headers = new JObject();
            foreach (var h in this.Request.Headers)
            {
                headers.Add(new JProperty(h.Key, h.Value));
            }
            jToken.Add(new JProperty("Headers", headers));

            var resp = new HttpResponseMessage();
            resp.Content = new StringContent(jToken.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8, "text/plain");
            return resp;
        }

        #endregion

        #region [Authorize] Actions

        [Route("Profile/Full")]
        [HttpGet]
        public async Task<Response<Models.UserProfileModel>> GetUserProfileModel_Full()
        {
            return await this.HandleResponseTask(async () =>
            {
                var identity = this.User.Identity as ClaimsIdentity;
                var userEmail = identity.GetEmail();

                var findUserResult = await this.UserManager.User_FindByEmailAsync(userEmail);

                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(String.Format(Resources.InvalidEmail,userEmail)) },
                                               HttpStatusCode.Forbidden);
                }


                var profile = new Models.UserProfileModel(findUserResult.Result, this.Carrier.ProfilesSettings.CorrectImageUri(findUserResult.Result.ImgURL));

                return new Response<Models.UserProfileModel>()
                {
                    Result = true,
                    Body = profile
                };
            });
        }

        [Route("Profile")]
        [HttpGet]
        public async Task<Response<Models.UserProfileModel>> GetUserProfileModel()
        {
            return await this.HandleResponseTask<Models.UserProfileModel>(async () =>
            {
                var identity = this.User.Identity as ClaimsIdentity;
                var userEmail = identity.GetEmail();

                var findUserResult = await this.UserManager.User_FindByEmailAsync(userEmail);

                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(String.Format(Resources.InvalidEmail,userEmail)) },
                                               HttpStatusCode.Forbidden);
                }

                var profile = new Models.UserProfileModel(findUserResult.Result, this.Carrier.ProfilesSettings.CorrectImageUri(findUserResult.Result.ImgURL));

                return new Response<Models.UserProfileModel>()
                {
                    Result = true,
                    Body = profile
                };
            });
        }

        [Route("Profile")]
        [HttpPost]
        public async Task<Response> UpdateUserProfileModel(Identity2.BL.Models.UpdateUserModel profile)
        {
            this.ValidateArguments(profile);

            return await this.HandleResponseTask(async () =>
            {
                var findUserResult = await this.UserManager.User_FindByEmailAsync(this.CurrentUser.Email);

                if (!findUserResult.ValidateSuccess())
                {
                    throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                               {new MessageCodeModel(InternalModels.MessagesCodesConstants.UPDATE_PROFILE_ERROR__INVALID_EMAIL, String.Format(Resources.InvalidEmail,profile.Email)) },
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
        [Route("Profile/Image")]
        public async Task<Response<string>> User_ImageUpload()
        {
            return await this.HandleResponseTask<string>(async () =>
            {
                //get user data
                var identity = this.User.Identity as ClaimsIdentity;
                long UserID = identity.GetUserId();

                var existsUser = await UserManager.User_FindByIDAsync(UserID);

                var provider = await Request.Content.ReadAsMultipartAsync<MultipartMemoryStreamProvider>(new MultipartMemoryStreamProvider());

                foreach (HttpContent content in provider.Contents)
                {
                    Stream stream = await content.ReadAsStreamAsync();

                    string fileExtension = null, contentType = null;

                    #region get extension and Content-Type

                    //first try - take content-type and extension from header
                    if (content.Headers.ContentType != null && !String.IsNullOrEmpty(content.Headers.ContentType.MediaType))
                    {
                        contentType = content.Headers.ContentType.MediaType.ToLower();

                        if (contentType.StartsWith(MIME_IMGAE_PREFIX))
                        {
                            fileExtension = $".{contentType.Substring(MIME_IMGAE_PREFIX.Length)}";
                        }
                    }

                    //second try - take content-type and extension from filename extension
                    if (String.IsNullOrEmpty(contentType))
                    {
                        if (!String.IsNullOrEmpty(content.Headers.ContentDisposition.FileName))
                        {
                            fileExtension = Path.GetExtension(content.Headers.ContentDisposition.FileName.Replace("\"", ""));

                            contentType = $"{MIME_IMGAE_PREFIX}{fileExtension.Substring(1)}";
                        }
                    }

                    //last - fail this request if still none
                    if (String.IsNullOrEmpty(contentType))
                    {
                        throw this.ThrowHttpResponseWithResultException(new MessageCodeModel[]
                                                                                    {
                                                                                    new MessageCodeModel("No Content-Type found in request")
                                                                                    });
                    }

                    #endregion

                    var filename = $"Profile_{CurrentUser.UserID}-{Guid.NewGuid().ToString().Substring(0, 4)}{fileExtension}";

                    using (var storageService = this.Carrier.ProfilesSettings.GetStorageService())
                    {
                        #region upload to storage service

                        var uploadRequest = new Connectors.StorageLibrary.UploadRequest()
                        {
                            ContentType = contentType,
                            TargetPath = filename,
                            ACL = Connectors.StorageLibrary.ACLControl.Private
                        };
                        var response = await storageService.UploadFileStreamAsync(stream, uploadRequest);

                        #endregion

                        if (response.Result)
                        {
                            string uri;
                            if (String.IsNullOrEmpty(this.Carrier.ProfilesSettings.Profiles_PublicAccessUrl))
                            {
                                uri = response.ObjectFullUrl;
                            }
                            else
                            {
                                uri = $"{this.Carrier.ProfilesSettings.Profiles_PublicAccessUrl}/{filename}";
                            }

                            //finally update user
                            var Result = await UserManager.User_ImageUploadAsync(UserID, filename);
                            if (Result != null && Result.Succeeded)
                            {
                                //delete old image, if any
                                if (!String.IsNullOrEmpty(existsUser.Result.ImgURL))
                                {
                                    try
                                    {
                                        await storageService.DeleteFileAsync(existsUser.Result.ImgURL);
                                    }
                                    catch { }
                                }

                                return new Response<string>(uri);
                            }
                        }
                    }
                }

                return new Response<string>()
                {
                    Result = false
                };
            });
        }

        [Route("Systems")]
        [HttpGet]
        public async Task<Response<Identity2.BL.Models.UserSystemsResponseModel>> GetSystems()
        {
            return await this.HandleResponseTask<Identity2.BL.Models.UserSystemsResponseModel>(async () =>
            {
                //check if admin
                var rolesResult = await UserManager.UserRoles_Roles(this.CurrentUser.UserID, Identity2.BL.IdentityConstants.ROLE_PRINCIPAL__GROUP_ID);
                if (!rolesResult.Succeeded)
                {
                    return new Response<AspNetIdentity.Identity2.BL.Models.UserSystemsResponseModel>()
                    {
                        Body = new AspNetIdentity.Identity2.BL.Models.UserSystemsResponseModel
                        {
                            Systems = new AspNetIdentity.Identity2.BL.Models.SystemInfoModel[0]
                        },
                        Result = false
                    };
                }

                var roles = rolesResult.Result
                       .ToArray();

                #region for SuperAdmin user get all system roles in system

                var isSuperAdmin = Identity2.BL.IdentityConstants.IsSuperAdmin(roles);
                if (isSuperAdmin)
                {
                    var systemRolesResult = await this.UserManager.System_RoleModels(Identity2.BL.IdentityConstants.ROLE_SYSTEMS__GROUP_ID);

                    if (!systemRolesResult.Succeeded)
                    {
                        return new Response<AspNetIdentity.Identity2.BL.Models.UserSystemsResponseModel>()
                        {
                            Messages = new MessageCodeModel[] { new MessageCodeModel(0, "Failed to get system roles for SuperAdmin user") },
                            Body = new AspNetIdentity.Identity2.BL.Models.UserSystemsResponseModel
                            {
                                Systems = new AspNetIdentity.Identity2.BL.Models.SystemInfoModel[0]
                            },
                            Result = false
                        };
                    }

                    roles = systemRolesResult.Result.ToArray();
                }

                #endregion

                var systems = roles
                                .Select(r => new Identity2.BL.Models.SystemInfoModel(r.RoleName))
                                .ToArray();


                //var systems = new List<Identity2.BL.Models.SystemInfoModel>();
                //constant systems
                //systems.Add(new Identity2.BL.Models.SystemInfoModel() { SystemName = SYSTEM_MF });

                return new Response<AspNetIdentity.Identity2.BL.Models.UserSystemsResponseModel>()
                {
                    Body = new AspNetIdentity.Identity2.BL.Models.UserSystemsResponseModel
                    {
                        Systems = systems.ToArray()
                    },
                    Result = true
                };
            });
        }

        #endregion
    }
}