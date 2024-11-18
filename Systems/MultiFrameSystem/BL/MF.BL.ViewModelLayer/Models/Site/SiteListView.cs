using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SiteListView0000
    {
        #region properties

        public string Name { get; set; }
        public long SiteID { get; set; }
        public SharedSiteListView0 SharingData { get; set; }
        public MapLocationView Location { get; set; }

        #endregion

        #region ctor

       /* public SiteListView(DAL.AdminLayer.Models.MainSiteShareData site)
        {
            Name = site.Name;
            SiteID = site.SiteID;
            SharingData = new SharedSiteListView(site);
            Location = new MapLocationView(site);
        }*/

        #endregion

        #region internal

       /* internal static SiteListView[] Get(DAL.AdminLayer.Models.MainSiteShareData[] sites)
        {
            return sites
                .Select(s => new SiteListView(s))
                .ToArray();
        }*/

        #endregion
    }
}
