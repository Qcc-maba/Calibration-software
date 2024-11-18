using Microsoft.AspNet.Identity;
using Microsoft.Owin;
using Owin;
using System;
using System.Linq;
using System.Collections.Generic;
using Microsoft.AspNet.Identity.Owin;
using System.Web.Http;
using System.Web.Mvc;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using System.Security.Claims;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.Common.CommonWebAPI;
using Microsoft.Owin.Security.Provider;
using Maba.Connectors.JsonHelpersLibrary;

[assembly: OwinStartup(typeof(Maba.AccountSystem.WebServices.Startup))]
namespace Maba.AccountSystem.WebServices
{
    public class Startup
    {
        public async Task ExternalProvider_ReturnEndPoint(ReturnEndpointContext context, Settings.WebServicesSettings Carrier)
        {
            var ticket = new Microsoft.Owin.Security.AuthenticationTicket(context.Identity, new Microsoft.Owin.Security.AuthenticationProperties());
            var externalLogin = OWINLibrary.Security.Externals.ExternalLoginData.FromIdentity(ticket.Identity);
            var _UserLoginInfo = new Identity2.BL.Models.UserLoginInfoModel(externalLogin.LoginProvider, externalLogin.ProviderKey);

            //create user manager
            using (var UserManager = Carrier.Generator_UserManager())
            {
                //look for exists user
                var _UserResult = await UserManager.User_FindByLoginAsync(_UserLoginInfo);

                var _User = _UserResult.Result;

                bool IsLockout = (_User != null || _UserResult.Succeeded) && _User.LockoutEnabled;

                if (_User == null || !_UserResult.Succeeded)
                {
                    #region Create new External login

                    var externalUser_Email = ticket.Identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Email);

                    var _createUser = new Identity2.BL.Models.CreateUserModel();
                    _createUser.Email = externalUser_Email.Value;

                    _createUser.FirstName = ticket.Identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.GivenName).Value;
                    _createUser.LastName = ticket.Identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Surname).Value;

                    #region phone number(at least one)

                    var externalUser_HomePhone = ticket.Identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.HomePhone);
                    var externalUser_MobilePhone = ticket.Identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.MobilePhone);
                    var externalUser_OtherPhone = ticket.Identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.OtherPhone);
                    var phoneClaim = externalUser_HomePhone ?? externalUser_MobilePhone ?? externalUser_OtherPhone ?? null;

                    if (phoneClaim != null)
                    {
                        _createUser.PhoneNumber = phoneClaim.Value;
                        _createUser.PhoneConfirmed = true;
                    }

                    #endregion

                    #region Create User (+ add claims etc..)

                    var addResult = await UserManager.User_CreateAsync(_createUser, true);
                    if (!addResult.Succeeded)
                    {
                        var error2_result = new HttpActionResults.RedirectExternalLoginResult(context.RedirectUri);
                        error2_result.AdditionalQueryParams.Add("IsSuccess", Boolean.FalseString.ToLower());
                        error2_result.AdditionalQueryParams.Add("Error", "2::Failed to create User");

                        context.RedirectUri = error2_result.CreateRedirectUri().ToString();
                        return;
                    }

                    #endregion

                    #region get user back (validation and get unique ID, dates etc..)

                    var findNewUserResult = await UserManager.User_FindByEmailAsync(externalUser_Email.Value);
                    if (!findNewUserResult.Succeeded)
                    {
                        var error2_result = new HttpActionResults.RedirectExternalLoginResult(context.RedirectUri);
                        error2_result.AdditionalQueryParams.Add("IsSuccess", Boolean.FalseString.ToLower());
                        error2_result.AdditionalQueryParams.Add("Error", "3::Failed to create User");

                        context.RedirectUri = error2_result.CreateRedirectUri().ToString();
                        return;
                    }

                    _User = findNewUserResult.Result;

                    #endregion

                    #region Add claims

                    //add claims
                    var claims = ticket.Identity.Claims
                                                    .Select(c => new Identity2.BL.Models.UserClaimModel(c.Type, c.Value));

                    var addClaimsResult = await UserManager.UserClaim_AddAsync(_User.Get_UserID(), claims);

                    #endregion

                    #region Add user login (this is external user)

                    var addLoginResult = await UserManager.UserLogin_AddAsync(_User.Get_UserID(), _UserLoginInfo);

                    if (!addLoginResult.Succeeded)
                    {
                        //delete user
                        await UserManager.User_DeleteAsync(_User.Get_UserID(), _User.Email);

                        var error3_result = new HttpActionResults.RedirectExternalLoginResult(context.RedirectUri);
                        error3_result.AdditionalQueryParams.Add("IsSuccess", Boolean.FalseString.ToLower());
                        error3_result.AdditionalQueryParams.Add("Error", "3::Failed to add User's login");

                        context.RedirectUri = error3_result.CreateRedirectUri().ToString();
                        return;
                    }

                    #endregion

                    #endregion
                }

                var accessToken = IsLockout ? null : await Contollers.LoginController.ProccessLogin(Carrier, _User.Get_UserID(), _User);

                //Response 3 - Known User (back to application)
                var login_result = new HttpActionResults.RedirectExternalLoginResult(context.RedirectUri);
                login_result.AdditionalQueryParams.Add("AccessTokenAccount", accessToken.Result ? accessToken.Body.AccountToken : "");
                login_result.AdditionalQueryParams.Add("IsSuccess", (IsLockout ? Boolean.FalseString : Boolean.TrueString).ToLower());

                context.RedirectUri = login_result.CreateRedirectUri().ToString();
                return;
            }
        }

        public void Configuration(IAppBuilder app)
        {
            var folder = System.Web.Hosting.HostingEnvironment.MapPath("~");

            var _Settings = Connectors.JsonHelpersLibrary.HierarchyFiles.TypeReader.ReadTypeContent<Settings.WebServicesSettings>(folder);

            #region validate settings

            var message = "One or more settings are missing. Fix the following: ";

            bool foundException = false;
            if (_Settings.DataProtectionOptions == null)
            {
                message += "DataProtectionOptions, ";
                foundException = true;
            }
            if (_Settings.EmailServicesSettings == null)
            {
                message += "EmailServicesSettings, ";
                foundException = true;
            }
            if (_Settings.Identity2ManagerSettings == null)
            {
                message += "Identity2ManagerSettings, ";
                foundException = true;
            }
            if (_Settings.LoginProviders == null)
            {
                message += "LoginProviders, ";
                foundException = true;
            }
            if (_Settings.ProfilesSettings == null)
            {
                message += "ProfilesSettings, ";
                foundException = true;
            }
            if (_Settings.ResourceLinksSettings == null)
            {
                message += "ResourceLinksSettings, ";
                foundException = true;
            }
            if (_Settings.SMSServicesSettings == null)
            {
                message += "SMSServicesSettings, ";
                foundException = true;
            }

            if (foundException)
            {
                throw new SystemException(message.Substring(0, message.Length - 2));
            }

            #endregion

            //supports HelpArea only in debug Mode
            if (_Settings.Properties.DebugMode)
            {
                AreaRegistration.RegisterAllAreas();
            }

            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            GlobalConfiguration.Configure((config) =>
            {
                CommonWebApiConfig.Register1(config);
                CommonWebApiConfig.Register2(config, _Settings);
            });

            #region Settings - generate repositories

            _Settings.Generator_UserManager = () => new Identity2.BL.Identity2UserManager(
                                                                          () => new Identity2.DAL.IdentityStore_SQL() { ThrowExceptions = true },
                                                                          _Settings.Identity2ManagerSettings, _Settings.DataProtectionOptions);


            #endregion

            #region Authentication providers 

            app.UseHydra2CommonAuthSettings(_Settings.DataProtectionOptions);

            #endregion

            #region external logins

            foreach (var provider in _Settings.LoginProviders.ExternalLogins.Where(p => p.IsEnabled))
            {
                switch (provider.Name)
                {
                    #region Google

                    //For Debugs Only:
                    //-----------------------
                    //origin localhost:10500
                    //ClientId      = "810861149327-usapsl6f0hfid76hlnh2m6c6u9lajl44.apps.googleusercontent.com"
                    //ClientSecret  = "ZqPrJ0eJ69OqEXy8_Ynm5Y6L"
                    //Scopes        = openid, profile, email, https://www.googleapis.com/auth/plus.me
                    case "Google":
                        var gogoleProvider = new OWINLibrary.Security.Externals.Google.GoogleAuthProvider()
                        {
                            ReturnEndpointFunc = (c) => ExternalProvider_ReturnEndPoint(c, _Settings)
                        };

                        var googleAuthOptions = new Microsoft.Owin.Security.Google.GoogleOAuth2AuthenticationOptions()
                        {
                            ClientId = provider.ClientId,
                            ClientSecret = provider.ClientSecret,
                            Provider = gogoleProvider,
                            SignInAsAuthenticationType = DefaultAuthenticationTypes.ExternalBearer
                        };

                        foreach (var scope in provider.Scopes)
                        {
                            googleAuthOptions.Scope.Add(scope);
                        }

                        app.UseGoogleAuthentication(googleAuthOptions);
                        break;

                    #endregion

                    #region Facebook

                    case "Facebook":
                        var facebookOptions = new OWINLibrary.Security.Externals.Facebook.Katana.FacebookAuthenticationOptions()
                        {
                            AppId = provider.ClientId,
                            AppSecret = provider.ClientSecret,
                            Provider = new OWINLibrary.Security.Externals.Facebook.FacebookAuthProvider()
                            {
                                ReturnEndpointFunc = (c) => ExternalProvider_ReturnEndPoint(c, _Settings),
                                OnAuthenticated = context =>
                                {
                                    return System.Threading.Tasks.Task.Run(() =>
                                        {
                                            if (context.User != null)
                                            {
                                                var first_name = context.User.GetValue("first_name");
                                                if (first_name != null)
                                                {
                                                    context.Identity.AddClaim(new System.Security.Claims.Claim(ClaimTypes.GivenName, first_name.ToString()));
                                                }
                                                var last_name = context.User.GetValue("last_name");
                                                if (last_name != null)
                                                {
                                                    context.Identity.AddClaim(new System.Security.Claims.Claim(ClaimTypes.Surname, last_name.ToString()));
                                                }
                                            }
                                        });
                                }
                            },
                            SignInAsAuthenticationType = DefaultAuthenticationTypes.ExternalBearer
                        };

                        foreach (var scope in provider.Scopes)
                        {
                            facebookOptions.Scope.Add(scope);
                        }

                        app.UseFacebookAuthentication(facebookOptions);

                        break;

                    #endregion

                    #region Twitter

                    case "Twitter":
                        //app.UseTwitterAuthentication(
                        //    consumerKey: "",
                        //    consumerSecret: "");

                        break;

                    #endregion

                    #region Microsoft

                    case "Microsoft":

                        //app.UseMicrosoftAccountAuthentication(
                        //    clientId: "",
                        //    clientSecret: "");
                        break;

                        #endregion
                }
            }

            #endregion

        }
    }
}