using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class User2Site
    {
        //site
        public long SiteID { get; set; }
        public long? ParentSiteID { get; set; }

        //security
        public bool RoleViewOnly { get; set; }
        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }

        public long LinkID { get; set; }
        public long LinkedUserID { get; set; }
        public long? LastActionUserID { get; set; }
        public bool? IsVerified { get; set; }
        public string Email { get; set; }

        public User2Site()
        {
            LinkedUserID = -1;
            LinkID = -1;
        }

        public override string ToString()
        {
            if (this.ParentSiteID.HasValue)
            {
                return $"S-{SiteID}";
            }
            else
            {
                return $"P-{SiteID}";
            }
        }
    }

    /*
    public class User2Site
    {
        //site
        public long SiteID { get; set; }
        public long? ParentSiteID { get; set; }
        public long TotalSitesDirect { get; set; }

        //root project
        public long? RootProjectID { set; get; }

        //security
        public bool RoleViewOnly { get; set; }
        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }

        //link details
        public long LinkID { get; set; }
        public long LinkedUserID { get; set; }
        public bool? IsVerified { get; set; }
        public bool IsDirectLink { get; set; }
        public bool IsShareBranch { get; set; }
        public long Level { get; set; }

        public User2Site()
        {
        }

        public override string ToString()
        {
            if (this.ParentSiteID.HasValue)
            {
                return $"S-{SiteID}";
            }
            else
            {
                return $"P-{SiteID}";
            }
        }
    }


    */
}
