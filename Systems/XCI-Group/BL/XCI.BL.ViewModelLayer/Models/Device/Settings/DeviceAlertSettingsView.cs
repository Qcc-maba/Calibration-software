using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class DeviceAlertSettingsView
    {
        #region properties

        public int AlertCode { get; set; }
        public string SN { get; set; }
        public bool IsEnable { get; set; }
        public bool SendSMS { get; set; }
        public bool SendEmail { get; set; }

        public bool Visible { get; set; }

        public string Name { get; set; }

        #endregion

        public DeviceAlertSettingsView()
        {

        }

    }
}
