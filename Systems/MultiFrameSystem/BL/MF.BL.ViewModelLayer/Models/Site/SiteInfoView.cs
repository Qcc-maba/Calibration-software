using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SiteInfoView
    {
        public long? ProjectID { set; get; }
        public string ProjectName { set; get; }
        public long SiteID { set; get; }
        public string SiteName { set; get; }
        public long SubSitesCount { get; set; }
        public TreeNodeView SharedView { set; get; }

        public SiteInfoView()
        {

        }

        public SiteInfoView(DAL.AdminLayer.Models.SiteInfo s)
        {
            ProjectID = s.RootSiteID;
            ProjectName = s.RootSiteName;
            SiteID = s.SiteID;
            SiteName = s.SiteName;

            SubSitesCount = s.TotalSitesDirect;
            SharedView = new TreeNodeView(s);
        }
    }
}
