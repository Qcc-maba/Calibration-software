using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class DeviceAlertSettingsView
    {
        #region properties

        public int AlertCode { get; set; }
        public string SN { get; set; }
        public bool IsEnable { get; set; }
        public bool IsSMSEnable { get; set; }
        public bool IsEmailEnable { get; set; }

        #endregion

        public DeviceAlertSettingsView(DAL.AdminLayer.Models.DeviceAlertSettings Settings, string sn)
        {
            this.AlertCode = Settings.AlertCode;
            this.IsEnable = Settings.IsEnable;
            this.IsSMSEnable = Settings.IsSMSEnable;
            this.IsEmailEnable = Settings.IsEmailEnable;
            SN = sn;
        }

        public DeviceAlertSettingsView()
        {

        }

    }
}
