using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class TreeNodeBase
    {
        public long SiteID { get; set; }
        public long? ParentSiteID { get; set; }

        public long? RootSiteID { set; get; }

        //security
        public bool RoleViewOnly { get; set; }
        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }

        public bool IsDirectLink { get; set; }
        public bool IsShareBranch { get; set; }
        public long Level { get; set; }
    }
}
