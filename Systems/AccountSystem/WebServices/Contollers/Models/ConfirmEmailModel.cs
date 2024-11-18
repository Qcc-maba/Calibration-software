using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class ConfirmEmailModel
    {
        public string Email { get; set; }

        public string ConfirmEmailToken { get; set; }
    }
}