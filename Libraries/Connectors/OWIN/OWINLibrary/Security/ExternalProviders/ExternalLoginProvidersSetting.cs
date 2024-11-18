using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Connectors.OWINLibrary.Security.Externals
{
    public class ExternalLoginProvidersSettings
    {
        #region properties

        public ExternalLoginProvider[] ExternalLogins { get; set; }

        #endregion

        #region ctor

        public ExternalLoginProvidersSettings()
        {
            #region init default External Providers

            ExternalLogins = new ExternalLoginProvider[]
            { 
                /// Google::
                /// --------------
                /// Create ID in address : https://console.developers.google.com
                /// Google+ API
                
                new ExternalLoginProvider()
                {
                    IsEnabled     = false,
                    Name          = "Google",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                },


                /// Facebook :: 
                /// --------------
                /// Create ID in address : https://developers.facebook.com/apps
                /// some help in http://www.asp.net/mvc/overview/security/create-an-aspnet-mvc-5-app-with-facebook-and-google-oauth2-and-openid-sign-on
                new ExternalLoginProvider()
                {
                    IsEnabled     = false,
                    Name          = "Facebook",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                },
                new ExternalLoginProvider()
                {
                    IsEnabled     = false,
                    Name          = "Twitter",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                },
                new ExternalLoginProvider()
                {
                    IsEnabled     = false,
                    Name          = "Microsoft",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                }
            };

            #endregion
        }

        #endregion
    }
}