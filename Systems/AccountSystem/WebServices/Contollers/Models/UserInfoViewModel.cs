using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class UserInfoViewModel
    {
        public string Email { get; set; }
        public string UserName { get; set; }
        public long UserID { get; set; }
        public string UserGUID { get; set; }
        public string GivenName { get; set; }
        public string Surename { get; set; }
    }
}