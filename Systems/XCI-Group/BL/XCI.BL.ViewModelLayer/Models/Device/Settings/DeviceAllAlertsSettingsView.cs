using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class DeviceAllAlertsSettingsView
    {
        //settings
        public bool IsAlertsEnabled { get; set; }
        public DeviceAlertSettingsView[] AlertSettings { get; set; }

        public decimal Threshold_OverCurrent { get; set; }
        public decimal Threshold_UnderCurrent { get; set; }
    }
}
