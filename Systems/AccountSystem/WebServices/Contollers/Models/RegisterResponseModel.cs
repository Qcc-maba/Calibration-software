using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class RegisterResponseModel
    {
        public string ShortenToken { get; set; }
        public bool SMSSent { get; set; }
    }
}
