using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SiteView
    {
        public DateTime CreationDate { get; set; }

        public string Name { get; set; }
        public long SiteID { get; set; }
        public long? ParentSiteID { get; set; }

        public TreeNodeView SharingData { get; set; }
        public MapLocationView Location { get; set; }

        public SiteView(DAL.AdminLayer.Models.MainSite site)
        {
            Name = site.Name;
            SiteID = site.SiteID;
            CreationDate = site.CreateDate;
            ParentSiteID = site.ParentSiteID;

            this.Location = new MapLocationView()
            {
                MapCenter = new MapPinLocationView()
                {
                    Latitude = string.IsNullOrEmpty(site.MapCenter_Latitude) ? 0 : decimal.Parse(site.MapCenter_Latitude),
                    Longitude = string.IsNullOrEmpty(site.MapCenter_Longitude) ? 0 : decimal.Parse(site.MapCenter_Longitude)
                }
                ,
                AutoBounds = site.MapCenter_AutoBounds,
                Mode = site.MapCenter_Mode,
                ZoomLevel = site.MapCenter_Zoom.GetValueOrDefault(0),
            };
        }
    }
}
