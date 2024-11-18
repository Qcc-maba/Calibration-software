using Microsoft.Owin.Security;
using Microsoft.Owin.Security.DataHandler;
using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Security
{
    public class DataProtectionProviderSettings
    {
        #region CONSTANTS

        public const string DEFAULT_SETTING_FILE_NAME = "DataProtectionProviderSettings";
        public const string DEFAULT_DATA_PROTECTION_PROVIDER = "Maba.Connectors.OWINLibrary.Cryptography.AES.AesDataProtectorProvider, Maba.Connectors.OWINLibrary";
        public const string DEFAULT_APP_NAME = "Maba Default DataProtectionProvider";

        #endregion

        #region properties

        public string ProtectionProviderType { get; set; }
        public string AppName { get; set; }
        public string Purposes { get; set; }

        #endregion

        #region ctor

        public DataProtectionProviderSettings()
        {
            AppName = DEFAULT_APP_NAME;
            ProtectionProviderType = DEFAULT_DATA_PROTECTION_PROVIDER;
        }

        #endregion

        #region public methods

        public IDataProtectionProvider CreateDataProtectionProvider()
        {
            var _type = Type.GetType(this.ProtectionProviderType ?? DEFAULT_DATA_PROTECTION_PROVIDER);
            var cons = _type.GetConstructors();
            var stringConstructor = cons.FirstOrDefault(c =>
                {
                    var prs = c.GetParameters();
                    return prs.Length == 1 && prs[0].ParameterType == typeof(string);
                });

            if (stringConstructor != null)
            {
                return (IDataProtectionProvider)Activator.CreateInstance(_type, new object[] { this.AppName ?? DEFAULT_APP_NAME });
            }
            else
            {
                return (IDataProtectionProvider)Activator.CreateInstance(_type);
            }
        }

        #endregion
    }
}
