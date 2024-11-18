using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class ForgotPasswordRequestModel
    {
        public string Email { get; set; }
        public string ResetPasswordPageUrl { get; set; }
    }
}
