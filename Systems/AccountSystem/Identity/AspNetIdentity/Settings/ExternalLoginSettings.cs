using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class ExternalLoginSettings
    {
        [XmlAttribute]
        public string Name { get; set; }

        [XmlAttribute]
        public bool IsEnabled { get; set; }

        public string ClientId { get; set; }

        public string ClientSecret { get; set; }

        public string ExtraProviderData { get; set; }

        public string[] Scopes { get; set; }

        #region ctor

        public ExternalLoginSettings()
        {
            IsEnabled = false;
        }

        #endregion

    }
}
