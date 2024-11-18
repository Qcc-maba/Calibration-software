using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models
{
    public class TreeNodeView
    {
        public long? RootSiteID { set; get; }

        //security
        public bool RoleViewOnly { get; set; }
        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }
        public bool IsDirectLink { get; set; }
        public bool IsShareBranch { get; set; }
        public long Level { get; set; }

        public TreeNodeView()
        {

        }
        public TreeNodeView(DAL.AdminLayer.Models.TreeNode node)
        {
            this.RootSiteID = node.RootSiteID;
            this.RoleViewOnly = node.RoleViewOnly;
            this.RoleModify = node.RoleModify;
            this.RoleControlRT = node.RoleControlRT;
            this.RoleAdmin = node.RoleAdmin;

            this.IsDirectLink = node.IsDirectLink;
            this.IsShareBranch = node.IsShareBranch;
            this.Level = node.Level;
        }
    }
}
