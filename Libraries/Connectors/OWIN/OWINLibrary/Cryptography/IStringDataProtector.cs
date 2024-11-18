using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Cryptography
{
    public interface IStringDataProtector
    {
        string Project(string unprotectedData);
        string Unproject(string protectedData);
    }
}
