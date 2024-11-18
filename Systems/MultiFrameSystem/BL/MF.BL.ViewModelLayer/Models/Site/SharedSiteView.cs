using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    /// <summary>
    /// When exists in regular site - means its shared site.
    /// Take care to consider the appropriate permissions.
    /// </summary>
    public class SharedSiteView0 : SharedSiteListView0
    {

        public SharedSiteView0(DAL.AdminLayer.Models.SiteInfo siteInfo)
            : base(null /*siteInfo*/)
        {

        }
        public SharedSiteView0()
        {

        }
        /* public long SharedUserID { get; set; }

         public DateTime ShareDate { get; set; }
         public DateTime? ShareApproveDate { get; set; }*/
    }
}