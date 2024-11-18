using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Web;
using Microsoft.Owin.Security;
using Microsoft.Owin.Security.DataHandler;
using System.Net.Http;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using Microsoft.Owin.Security.Google;

namespace Maba.Connectors.OWINLibrary.Security.Externals.Google
{
    public class GoogleAuthProvider : IGoogleOAuth2AuthenticationProvider
    {
        #region members

        public Func<GoogleOAuth2ReturnEndpointContext, Task> ReturnEndpointFunc { get; set; }

        #endregion

        #region ctor

        public GoogleAuthProvider()
        {

        }
        #endregion

        #region IGoogleOAuth2AuthenticationProvider members

        public void ApplyRedirect(GoogleOAuth2ApplyRedirectContext context)
        {
            context.Response.Redirect(context.RedirectUri);
        }

        public Task Authenticated(GoogleOAuth2AuthenticatedContext context)
        {
            //not necessarily needed.
            context.Identity.AddClaim(new Claim("ExternalAccessToken", context.AccessToken));

            return Task.FromResult<object>(null);
        }

        public Task ReturnEndpoint(GoogleOAuth2ReturnEndpointContext context)
        {
            if (ReturnEndpointFunc != null)
            {
                return ReturnEndpointFunc(context);
            }

            return Task.FromResult<object>(null);
        }

        #endregion
    }
}