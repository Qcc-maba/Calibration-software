using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class ProjectTreeContainerView
    {
        public string Name { get; set; }
        public long SiteID { get; set; }
        //public long RootProjectID { get; set; }


        public List<ProjectTreeContainerView> Sites { get; set; }
        public TreeNodeView SharingData { get; set; }
        public long? ParentSiteID { get; set; }

        public ProjectTreeContainerView()
        {

        }

        public override string ToString()
        {
            return string.Format("ProjectID:{0}", SiteID);
        }
    }
}
