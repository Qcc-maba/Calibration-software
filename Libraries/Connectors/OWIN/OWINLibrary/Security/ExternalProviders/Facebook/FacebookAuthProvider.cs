using System;
using System.Web;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Owin.Security;
using Microsoft.Owin.Security.DataHandler;
using System.Net.Http;
using OWINLibrary = Maba.Connectors.OWINLibrary;

namespace Maba.Connectors.OWINLibrary.Security.Externals.Facebook
{
    public class FacebookAuthProvider : Katana.Provider.FacebookAuthenticationProvider
    {
        #region members

        public Func<Katana.Provider.FacebookReturnEndpointContext, Task> ReturnEndpointFunc { get; set; }

        #endregion

        #region ctor

        public FacebookAuthProvider()
        {

        }

        #endregion

        #region IFacebookAuthenticationProvider members

        public override void ApplyRedirect(Katana.Provider.FacebookApplyRedirectContext context)
        {
            base.ApplyRedirect(context);
            context.Response.Redirect(context.RedirectUri);

        }

        public override Task Authenticated(Katana.Provider.FacebookAuthenticatedContext context)
        {
            base.Authenticated(context);
            //not necessarily needed.
            context.Identity.AddClaim(new Claim("ExternalAccessToken", context.AccessToken));

            return Task.FromResult<object>(null);
        }

        public override Task ReturnEndpoint(Katana.Provider.FacebookReturnEndpointContext context)
        {
            if (ReturnEndpointFunc!=null)
            {
                return ReturnEndpointFunc(context);
            }

            return Task.FromResult<object>(null);
        }

        #endregion
    }
}
