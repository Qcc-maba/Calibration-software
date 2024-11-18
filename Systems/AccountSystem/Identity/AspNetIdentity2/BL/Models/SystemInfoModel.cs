using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class SystemInfoModel
    {
        public string SystemName { get; set; }

        public SystemInfoModel()
        {

        }

        public SystemInfoModel(string system)
        {
            SystemName = system;
        }
    }
}