using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class DeviceAlertInSiteView
    {
        public long SiteID { get; set; }
        public string SiteName { get; set; }
        public long DeviceID { get; set; }
        public bool IsAlertsEnabled { get; set; }
        public bool IsDeviceAlertsEnabled { get; set; }
        public string DeviceName { set; get; }
        public string SN { set; get; }

        public DeviceAlertInSiteView()
        {

        }

        public DeviceAlertInSiteView(DAL.AdminLayer.Models.DeviceAlertSettings_2Site setting)
        {
            if (setting == null)
                return;

            SiteID = setting.SiteID;
            SiteName = setting.SiteName;
            DeviceID = setting.DeviceID;
            IsAlertsEnabled = setting.IsAlertsEnabled;
            IsDeviceAlertsEnabled = setting.IsDeviceAlertsEnabled;
            DeviceName = setting.DeviceName;
            SN = setting.SN;
        }
    }

}
