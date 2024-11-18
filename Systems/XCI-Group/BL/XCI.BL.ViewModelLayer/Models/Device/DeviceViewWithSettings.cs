using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device
{
    public class DeviceViewWithSettings : DeviceView
    {
        public Settings.DeviceSettingsView DeviceSettingsView { set; get; }

        public DeviceViewWithSettings(DAL.DataAccessLayer.Models.Device.DeviceBase device, Settings.DeviceSettingsView setting)
            :base(device)
        {
            DeviceSettingsView = setting;

        }

        public DeviceViewWithSettings()
        {

        }

    }

}
