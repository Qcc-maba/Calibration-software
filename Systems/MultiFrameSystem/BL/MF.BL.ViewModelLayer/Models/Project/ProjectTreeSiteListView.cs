using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class ProjectTreeSiteListView
    {
        public string Name { get; set; }
        public long SiteID { get; set; }

        public TreeNodeView SharingData { get; set; }

        /*public static ProjectTreeSiteListView[] Get(DAL.AdminLayer.Models.MainSiteShareData[] site)
        {
            ProjectTreeSiteListView[] newArray = new ProjectTreeSiteListView[site.Length];
            var i = 0;
            foreach (var item in site)
            {
                newArray[i] = new ProjectTreeSiteListView()
                { 
                    Name = item.Name, 
                    SiteID = item.SiteID, 
                    SharingData = new Site.SharedSiteListView(item)
                };
                i++;
            }
            
            return newArray;
        }*/
    }
}