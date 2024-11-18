using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class UserSystemsResponseModel
    {
        public AspNetIdentity.Identity2.BL.Models.SystemInfoModel[] Systems { get; set; }
    }
}
