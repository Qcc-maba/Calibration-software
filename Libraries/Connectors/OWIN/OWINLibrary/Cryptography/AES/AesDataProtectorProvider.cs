using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Cryptography.AES
{
    public class AesDataProtectorProvider : IDataProtectionProvider
    {
        public IDataProtector Create(params string[] purposes)
        {
            if (purposes == null)
            {
                purposes = new string[0];
            }
            else if (purposes.Length == 1 && String.IsNullOrEmpty(purposes[0]))
            {
                purposes = new string[0];
            }

            return new AesDataProtector(purposes != null && purposes.Length > 0 ? string.Concat(purposes) : null);
        }
    }

}
