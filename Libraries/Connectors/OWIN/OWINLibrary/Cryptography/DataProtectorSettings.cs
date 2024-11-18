using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Cryptography
{
    public class DataProtectorSettings
    {
        #region CONSTANTS

        public const string DEFAULT_DATA_PROTECTOR_NAME = "System.Security.Cryptography.DpapiDataProtector, System.Security";
        public const string DEFAULT_APP_NAME = "MultiFrame System View-Mode-lLibrary";

        #endregion

        #region properties

        public string DataProtectorType { get; set; }
        public string AppName { get; set; }
        public string PrimaryPurpose { get; set; }
        public string SpecificPurpose { get; set; }

        #endregion

        #region ctor

        public DataProtectorSettings()
        {
            AppName = DEFAULT_APP_NAME;
            DataProtectorType = DEFAULT_DATA_PROTECTOR_NAME;
        }

        #endregion

        #region public methods

        public DataProtector CreateDataProtector()
        {
            DataProtector dataProtector;

            var _type = Type.GetType(this.DataProtectorType ?? DEFAULT_DATA_PROTECTOR_NAME);
            string[] _specificPurposes = null;
            if (String.IsNullOrEmpty(SpecificPurpose))
            {
                _specificPurposes = SpecificPurpose
                                        .Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                                        .Select(s => s.Trim())
                                        .ToArray();

                dataProtector = (DataProtector)Activator.CreateInstance(_type, new object[] { this.AppName ?? DEFAULT_APP_NAME, PrimaryPurpose, _specificPurposes });
            }
            else
            {
                dataProtector = (DataProtector)Activator.CreateInstance(_type, new object[] { this.AppName ?? DEFAULT_APP_NAME, PrimaryPurpose });
            }

            return dataProtector;
        }

        #endregion
    }
}
