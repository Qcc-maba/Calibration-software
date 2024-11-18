using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class MainSiteShareData : MainSite
    {
        public DateTime ShareApproveDate { set; get; }
        public bool? IsVerified { get; set; }
        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }
    }
}
