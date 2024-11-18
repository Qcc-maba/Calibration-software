using Owin;
using Microsoft.Owin;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI
{
    public static class CommonOWINConfig
    {
        public static void UseHydra2CommonAuthSettings(this IAppBuilder app, OWINLibrary.Security.DataProtectionProviderSettings dataProtectionSettings)
        {
            var dataProtectionProvider = dataProtectionSettings.CreateDataProtectionProvider();

            var tokenHelper = AccessTokenHelper.CreateAccessTokenHelper(dataProtectionProvider, dataProtectionSettings.Purposes);
            app.UseOAuthBearerAuthentication(new Microsoft.Owin.Security.OAuth.OAuthBearerAuthenticationOptions()
            {
                AccessTokenFormat = tokenHelper.TicketDataProtector,
                Provider = new OWINLibrary.Security.Providers.OAuthBearerAuthenticationProvider(),
                AuthenticationMode = Microsoft.Owin.Security.AuthenticationMode.Active
            });
        }
    }
}
