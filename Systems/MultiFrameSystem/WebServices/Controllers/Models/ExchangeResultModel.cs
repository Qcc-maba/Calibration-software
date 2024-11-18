using Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers.Models
{
    public class ExchangeResultModel
    {
        public ExchangeView ExchangeData { get; set; }
        public ApplicationUserModel UserModel { get; set; }

        public string NewToken { get; set; }
    }
}
