using Microsoft.Owin.Security.OAuth;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;

namespace Maba.Connectors.OWINLibrary.Security.Providers
{
    public class OAuthBearerAuthenticationProvider : IOAuthBearerAuthenticationProvider
    {
        public System.Threading.Tasks.Task ApplyChallenge(OAuthChallengeContext context)
        {
            return Task.FromResult<object>(null);
        }

        public System.Threading.Tasks.Task RequestToken(OAuthRequestTokenContext context)
        {
            return Task.FromResult<object>(null);
        }

        public System.Threading.Tasks.Task ValidateIdentity(OAuthValidateIdentityContext context)
        {
            
            return Task.FromResult<object>(null);
        }
    }
}