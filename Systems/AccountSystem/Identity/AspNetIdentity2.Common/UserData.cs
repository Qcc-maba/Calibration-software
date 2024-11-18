using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Common
{
    public class UserData
    {
        public string LoginProvider { get; set; }
        public string UserName { get; set; }
        public string Email { get; set; }
        public string UserGUID { get; set; }
        public long UserID { get; set; }
        public string Surename { get; set; }
        public string GivenName { get; set; }
    }
}
