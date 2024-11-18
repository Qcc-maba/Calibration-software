using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class AlertThresholdSettingsView
    {
        #region properties

        public decimal? OverCurrentThreshold { get; set; }

        public decimal? UnderCurrentThreshold { get; set; }

        public bool IsAlertsEnabled { get; set; }

        #endregion

        public AlertThresholdSettingsView()
        {
            IsAlertsEnabled = true;
        }

        public AlertThresholdSettingsView(AlertThresholdSettings s)
        {
            IsAlertsEnabled = true;

            if (s != null)
            {
                OverCurrentThreshold = s.OverCurrentThreshold;
                UnderCurrentThreshold = s.UnderCurrentThreshold;
                this.IsAlertsEnabled = s.IsAlertsEnabled;
            }
        }

        public static AlertThresholdSettingsView CreateDefault()
        {
            return new AlertThresholdSettingsView()
            {
                IsAlertsEnabled = false,
                OverCurrentThreshold = 50,
                UnderCurrentThreshold = 50
            };
                 
        }

    }
}
