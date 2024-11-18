using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SiteMapContainerView
    {
        public string Name { get; set; }
        public long SiteID { get; set; }

        public MapLocationView Location { get; set; }

        public Device.DeviceListView[] Devices { get; set; }
        public TreeNodeView SharedView { set; get; }


        public SiteMapContainerView(DAL.AdminLayer.Models.MainSite site, DAL.AdminLayer.Models.DeviceInfoWithParent[] _Devices)
        {
            //site
            Name = site.Name;
            SiteID = site.SiteID;
            Location = new MapLocationView(site);

            //devices
            Devices = _Devices
                        .Select(u => new Device.DeviceListView(u))
                        .ToArray();
        }
    }
}
