using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Security.Externals
{
    public class ExternalLoginProvider
    {
        public string Name { get; set; }

        public bool IsEnabled { get; set; }

        public string ClientId { get; set; }

        public string ClientSecret { get; set; }

        public string ExtraProviderData { get; set; }

        public string[] Scopes { get; set; }

        #region ctor

        public ExternalLoginProvider()
        {
            IsEnabled = false;
        }

        #endregion
    }
}
