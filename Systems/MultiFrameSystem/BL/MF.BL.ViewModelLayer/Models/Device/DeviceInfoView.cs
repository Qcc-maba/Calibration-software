using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class DeviceInfoView
    {
        public string DeviceName { get; set; }
        public long DeviceID { get; set; }
        public string SN { get; set; }
        public Site.SiteInfoView ParentSiteInfo { get; set; }
        public Device.DeviceListView[] OtherDevicesView { set; get; }
    }
}
