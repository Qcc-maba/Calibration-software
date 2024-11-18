using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SharedSiteListView0
    {
        #region properties

        public long SiteID { get; set; }
        public bool IsDirectShare { get; set; }

        public bool RoleModify { get; set; }
        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }
        public bool RoleViewOnly { get; set; }

        public bool? IsVerified { get; set; }


        #endregion

        #region ctor(s)

        public SharedSiteListView0()
        {

        }

        public SharedSiteListView0(DAL.AdminLayer.Models.User2Site site)
        {
            SiteID = site.SiteID;

            RoleControlRT = site.RoleControlRT;
            RoleModify = site.RoleModify;
            RoleAdmin = site.RoleAdmin;
            RoleViewOnly = site.RoleViewOnly;
        }

        /* public SharedSiteListView(DAL.AdminLayer.Models.MainSiteShareData site)
         {
             RoleControlRT = site.RoleControlRT;
             RoleModify = site.RoleModify;
             RoleAdmin = site.RoleAdmin;
         }*/

        #endregion
    }
}