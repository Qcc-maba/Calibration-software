using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    [XmlInclude(typeof(PhoneTwoFactorProvider))]
    [XmlInclude(typeof(EmailTwoFactorProvider))]
    public abstract class TwoFactorProvider
    {
        [XmlAttribute]
        public abstract string ProviderName { get; }

        [XmlAttribute]
        public bool IsEnabled { get; set; }
    }
}
