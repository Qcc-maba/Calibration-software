using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Security
{
    public class ConfirmEmailData
    {
        public string Email { get; set; }
        public DateTime ExpireDate { get; set; }
        public DateTime IssueDate { get; set; }
    }
}
