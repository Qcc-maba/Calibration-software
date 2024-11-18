using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Security
{
    public interface IDataProtector<T> where T : class
    {
        byte[] Protect(T obj, string purpose = null);
        string Protect2String(T obj, string purpose = null);

        T Unprotect(byte[] protectedData, string purpose = null);
        T Unprotect(string protectedData, string purpose = null);
    }
}
