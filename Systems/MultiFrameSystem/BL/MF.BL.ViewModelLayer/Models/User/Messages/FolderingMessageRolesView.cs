using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User.Messages
{
    public class FolderingMessageRolesView
    {
        public long SiteID { get; set; }
        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }
        public bool RoleViewOnly { get; set; }

        public FolderingMessageRolesView()
        {

        }

        public FolderingMessageRolesView(DAL.AdminLayer.Models.User2Site u2s)
        {
            this.SiteID = u2s.SiteID;
            this.RoleViewOnly = u2s.RoleViewOnly;
            this.RoleModify = u2s.RoleModify;
            this.RoleControlRT = u2s.RoleControlRT;
            this.RoleAdmin = u2s.RoleAdmin;
        }

        public FolderingMessageRolesView(DAL.AdminLayer.Models.TreeNode node)
        {
            this.SiteID = node.SiteID;
            this.RoleViewOnly = node.RoleViewOnly;
            this.RoleModify = node.RoleModify;
            this.RoleControlRT = node.RoleControlRT;
            this.RoleAdmin = node.RoleAdmin;
        }
    }
}
