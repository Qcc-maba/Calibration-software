using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class PhoneTwoFactorProvider : TwoFactorProvider
    {
        public const string PROVIDER_NAME = "PhoneCode";

        public override string ProviderName
        {
            get { return PROVIDER_NAME; }
        }
        public string MessageFormat { get; set; }
    }
}
