using System;
using System.Linq;
using System.Collections.Generic;
using System.Security.Claims;
using System.Web;

namespace Maba.Connectors.OWINLibrary.Security.Externals
{
    public class ExternalLoginData
    {
        public string LoginProvider { get; set; }
        public string ProviderKey { get; set; }
        public string UserName { get; set; }

        public static ExternalLoginData FromIdentity(ClaimsIdentity identity)
        {
            if (identity == null)
            {
                return null;
            }

            Claim providerKeyClaim = identity.FindFirst(ClaimTypes.NameIdentifier);

            if (providerKeyClaim == null || String.IsNullOrEmpty(providerKeyClaim.Issuer)
                || String.IsNullOrEmpty(providerKeyClaim.Value))
            {
                return null;
            }

            if (providerKeyClaim.Issuer == ClaimsIdentity.DefaultIssuer)
            {
                return null;
            }

            var name = identity.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Name);

            return new ExternalLoginData
            {
                LoginProvider = providerKeyClaim.Issuer,
                ProviderKey = providerKeyClaim.Value,
                UserName = name == null ? "" : name.Value
            };
        }
    }

}