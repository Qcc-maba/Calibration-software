using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class DeviceSettingsViewBase
    {
        public bool UserWeatherSavingAlgorithm { get; set; }

        public DateTime? HoldUntil { get; set; }

        public bool UseSiteSessionSettings { get; set; }

        public DaySettingsView[] Days { get; set; }

        public int? HoldType { get; set; }


        public DeviceSettingsViewBase()
        {

        }

        public DeviceSettingsViewBase(DeviceSettings Settings, DaySettings[] DaySetting = null)
        {
            if (Settings != null)
            {
                UserWeatherSavingAlgorithm = Settings.UserWeatherSavingAlgorithm;
                HoldUntil = Settings.HoldUntil;
                UseSiteSessionSettings = Settings.UseSiteSessionSettings;
                HoldType = Settings.HoldType;
            }
            if (DaySetting != null)
            {
                Days = DaySetting.Select(d => new DaySettingsView()).ToArray();
            }
        }
    }
}
