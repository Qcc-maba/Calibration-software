using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Cryptography
{
    public class ASCIIDataProtector : IStringDataProtector
    {
        #region members

        private DataProtector _DataProtector = null;

        #endregion

        #region ctor

        public ASCIIDataProtector(DataProtector dataProtector)
        {
            _DataProtector = dataProtector;
        }

        #endregion

        #region IStringDataProtector members

        public string Unproject(string protectedData)
        {
            var protectedBuffer = System.Text.ASCIIEncoding.ASCII.GetBytes(protectedData);
            var unprotectedBuffer = _DataProtector.Unprotect(protectedBuffer);

            return System.Text.ASCIIEncoding.ASCII.GetString(unprotectedBuffer);
        }

        public string Project(string unprotectedData)
        {
            var unprotectedBuffer = System.Text.ASCIIEncoding.ASCII.GetBytes(unprotectedData);
            var protectedBuffer = _DataProtector.Protect(unprotectedBuffer);

            return System.Text.ASCIIEncoding.ASCII.GetString(protectedBuffer);
        }

        #endregion
    }
}
