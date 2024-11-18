using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class DeviceAlertSettings_2Site
    {
        public long DeviceID { get; set; }
        public string DeviceName { set; get; }
        public bool IsDeviceAlertsEnabled { get; set; }
        public string SN { set; get; }
        public string SiteName { get; set; }
        public long SiteID { get; set; }
        public bool IsAlertsEnabled { get; set; }

        public bool RoleModify { get; set; }
        public bool RoleAdmin { get; set; }
        public bool RoleViewOnly { get; set; }
        public bool RoleControlRT { get; set; }

    }
}
