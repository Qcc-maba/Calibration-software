using Microsoft.Owin.Security;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;

namespace Maba.AccountSystem.WebServices.HttpActionResults
{
    public class ChallengeResult : IHttpActionResult
    {
        #region properties

        public string LoginProvider { get; set; }
        public HttpRequestMessage Request { get; set; }
        public AuthenticationProperties Properties { get; set; }
        public string RedirectUri { get; set; }

        #endregion

        #region ctor

        public ChallengeResult(string loginProvider, ApiController controller, string redirectUri = null)
        {
            LoginProvider = loginProvider;
            Request = controller.Request;
            RedirectUri = redirectUri;
        }

        #endregion

        #region IHttpActionResult members

        public System.Threading.Tasks.Task<System.Net.Http.HttpResponseMessage> ExecuteAsync(System.Threading.CancellationToken cancellationToken)
        {
            if (!String.IsNullOrEmpty(RedirectUri))
            {
                var properties = new AuthenticationProperties { RedirectUri = RedirectUri };
                Request.GetOwinContext().Authentication.Challenge(properties, LoginProvider);
            }
            else
            {
                Request.GetOwinContext().Authentication.Challenge(LoginProvider);
            }

            HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.Unauthorized);
            response.RequestMessage = Request;
            return Task.FromResult(response);
        }

        #endregion
    }
}