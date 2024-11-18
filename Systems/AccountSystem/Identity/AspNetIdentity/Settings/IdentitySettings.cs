using Maba.Connectors.OWINLibrary.Security;
using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class IdentitySettings
    {
        #region properties

        public ExternalLoginSettings[] ExternalLogins { get; set; }
        public DataProtectionProviderSettings DataProtectionProvider { get; set; }
        public PasswordValidatorSettings PasswordValidator { get; set; }
        public UserValidatorSettings UserValidator { get; set; }
        public SecuritySettings Security { get; set; }
        public TwoFactorProvider[] TokenProviders { get; set; }

        #endregion

        #region ctor

        public IdentitySettings()
        {
            DataProtectionProvider = new DataProtectionProviderSettings();
            PasswordValidator = new PasswordValidatorSettings();
            UserValidator = new UserValidatorSettings();
            Security = new SecuritySettings();

            #region define default providers

            TokenProviders = new TwoFactorProvider[]
            {
                new PhoneTwoFactorProvider()
                {
                    MessageFormat    = "Your security code is: {0}"
                },
                new EmailTwoFactorProvider()
                {
                    Subject              = "SecurityCode",
                    BodyFormat           = "Your security code is {0}"
                }
            };

            #endregion

            #region define default logins

            ExternalLogins = new ExternalLoginSettings[]
            { 
                new ExternalLoginSettings()
                {
                    IsEnabled     = false,
                    Name          = "Google",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                },
                new ExternalLoginSettings()
                {
                    IsEnabled     = false,
                    Name          = "Facebook",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                },
                new ExternalLoginSettings()
                {
                    IsEnabled     = false,
                    Name          = "Twitter",
                    ClientId      = "ClientId",
                    ClientSecret  = "Secret",
                    Scopes        = new string []{"openid","profile","email"}
                },
                new ExternalLoginSettings()
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
