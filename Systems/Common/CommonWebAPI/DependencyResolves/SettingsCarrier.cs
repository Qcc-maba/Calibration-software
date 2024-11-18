using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.DependencyResolves
{
    public abstract class BaseSettingsCarrier
    {
        #region properties

        public OWINLibrary.Security.DataProtectionProviderSettings DataProtectionOptions { get; set; }

        #endregion

        #region ctor

        public BaseSettingsCarrier()
        {
        }

        #endregion
    }
}
