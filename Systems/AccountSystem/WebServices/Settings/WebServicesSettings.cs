using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Xml.Serialization;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using System.ComponentModel;
using System.Collections.Specialized;
using Maba.Connectors.JsonHelpersLibrary;

namespace Maba.AccountSystem.WebServices.Settings
{
    public class WebServicesSettings : Hydra2.Systems.Common.CommonWebAPI.DependencyResolves.BaseSettingsCarrier
    {

        #region properties
        public GeneralProperties Properties { get; set; }
        public OWINLibrary.Security.Externals.ExternalLoginProvidersSettings LoginProviders { get; set; }
        public Connectors.EmailServices.EmailServiceSettings EmailServicesSettings { get; set; }
        public Connectors.SMSServices.SMSServiceSettings SMSServicesSettings { get; set; }
        public StorageSettings ProfilesSettings { get; set; }
        public Identity2.Settings.ManagerSettings Identity2ManagerSettings { get; set; }
        public ResourceLinkSettings ResourceLinksSettings { get; set; }

        #endregion

        internal Func<Identity2.BL.Identity2UserManager> Generator_UserManager { get; set; }

        #region ctor

        public WebServicesSettings()
            : base()
        {
            Properties = new GeneralProperties();
        }

        #endregion

        #region methods        

        public Connectors.EmailServices.IEmailSenderConnector GetEmailService()
        {
            if (EmailServicesSettings == null)
                return null;

            var emailService = Connectors.EmailServices.EmailServiceSettings.Create(EmailServicesSettings);
            return emailService;
        }

        public Connectors.SMSServices.ISMSSenderConnector GetSMSService()
        {
            if (SMSServicesSettings == null || !SMSServicesSettings.InEnabled)
                return null;

            var smsService = Connectors.SMSServices.SMSServiceSettings.Create(SMSServicesSettings);
            return smsService;
        }

        #endregion
    }
}