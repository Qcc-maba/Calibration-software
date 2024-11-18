using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class PhoneVerificationCode
    {
        public long UserID { get; set; }
        public string PhoneNumberChangeToken { get; set; }

    }
}
