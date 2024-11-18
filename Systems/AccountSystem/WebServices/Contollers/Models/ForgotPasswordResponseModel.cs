using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class ForgotPasswordResponseModel
    {
        public string ShortenToken { get; set; }
        public string SentEmail { get; set; }
    }
}
