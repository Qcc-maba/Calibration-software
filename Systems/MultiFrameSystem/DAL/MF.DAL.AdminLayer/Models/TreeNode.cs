using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class TreeNode : TreeNodeBase
    {
        //site
        public string SiteName { set; get; }

        //root project
        public string RootSiteName { set; get; }

        //link details
        public long LinkID { get; set; }
        public long LinkedUserID { get; set; }
        public bool? IsVerified { get; set; }

        /// <summary>
        /// used only for adding new user without knowing his ID
        /// </summary>
        // public string Email { get; set; }

        public TreeNode()
        {
        }

        public override string ToString()
        {
            if (this.ParentSiteID.HasValue)
            {
                return $"S-{SiteID}::{SiteName}";
            }
            else
            {
                return $"P-{SiteID}::{SiteName}";
            }
        }

    }
}
