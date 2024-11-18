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

namespace Maba.AccountSystem.WebServices.Contollers
{
    [RoutePrefix("LocalAdmin")]
    [OWIN.Security.Attributes.HostFilterAuthorize(
        OnlyLoopback = true)]
    [Authorize]
    public class LocalAdminController : BaseController
    {
        #region [AllowAnonymous]

        [HttpPost]
        [AllowAnonymous]
        [Route("FAKE/ResetEmailToken")]
        public async Task<HttpResponseMessage> BuildResetEmailToken(Models.ForgotPasswordRequestModel request)
        {
            var resp = new HttpResponseMessage();
            var jToken = new Newtonsoft.Json.Linq.JObject();

            var findUserResult = await UserManager.User_FindByEmailAsync(request.Email);
            if (!findUserResult.ValidateSuccess())
            {
                jToken.Add(new JProperty("found", "false"));

                resp.StatusCode = HttpStatusCode.Forbidden;
            }
            else
            {
                var user = findUserResult.Result;
                var resetToken = await UserManager.User_GeneratePasswordResetTokenAsync(user.Get_UserID());

                jToken.Add(new JProperty("found", "true"));
                jToken.Add(new JProperty("token", resetToken.Result));

                resp.StatusCode = HttpStatusCode.OK;
            }

            resp.Content = new StringContent(jToken.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8, "text/plain");
            return resp;
        }

        [HttpPost]
        [AllowAnonymous]
        [Route("FAKE/User")]
        public async Task<HttpResponseMessage> BuildUserToken(Models.UserInfoViewModel user)
        {
            var resp = new HttpResponseMessage();
            var jToken = new Newtonsoft.Json.Linq.JObject();

            var findUserResult = await UserManager.User_FindByEmailAsync(user.Email);
            if (findUserResult.Succeeded && findUserResult.Result != null)
            {
                var response = await LoginController.ProccessLogin(this.Carrier, findUserResult.Result.Get_UserID(), findUserResult.Result);

                //build response
                jToken.Add(new JProperty("found", "true"));
                jToken.Add(new JProperty("result", response.Result));
                jToken.Add(new JProperty("EmailConfirmed", findUserResult.Result.EmailConfirmed));
                jToken.Add(new JProperty("token", response.Body.AccountToken));
                jToken.Add(new JProperty("User", JObject.FromObject(user)));
            }
            else
            {
                //build response
                jToken.Add(new JProperty("found", "false"));
                jToken.Add(new JProperty("result", "false"));
                jToken.Add(new JProperty("User", JObject.FromObject(user)));
            }

            resp.Content = new StringContent(jToken.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8, "text/plain");
            return resp;
        }

        [HttpGet]
        [AllowAnonymous]
        [Route("FAKE/ConfirmEmailToken")]
        public async Task<Response<string>> BuildConfirmEmailToken(string Email)
        {
            var confirmEmailTokenResult = await UserManager.User_GenerateEmailConfirmationTokenAsync(Email);

            return new Response<string>()
            {
                Body = confirmEmailTokenResult.Result,
                Result = true
            };
        }

        #endregion
    }
}
