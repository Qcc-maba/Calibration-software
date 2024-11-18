using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Settings
{
    public class EmailTwoFactorProvider : TwoFactorProvider
    {
        public const string PROVIDER_NAME = "EmailCode";

        public override string ProviderName
        {
            get { return PROVIDER_NAME; }
        }
        public string BodyFormat { get; set; }
        public string Subject { get; set; }
    }
}
