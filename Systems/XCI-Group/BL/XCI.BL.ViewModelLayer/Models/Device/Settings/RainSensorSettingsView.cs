using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class RainSensorSettingsView
    {
        public enum RainSensorTypes
        {
            NC = 1,
            NO = 2
        }

        public bool IsEnabled { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public RainSensorTypes SensorType { get; set; }

        public int RainOffMinDuration { get; set; }
        public int RainStabilitySecTime { get; set; }

        public int? SensorInputNumber { get; set; }

        public RainSensorSettingsView()
        {

        }

        public RainSensorSettingsView(RainSensorSettings setting)
        {
            if (setting == null)
                return;
            SensorType = (RainSensorTypes)setting.SensorType;
            RainOffMinDuration = setting.RainOffMinDuration;
            RainStabilitySecTime = setting.RainStabilitySecTime;
            SensorInputNumber = setting.SensorInputNumber;
            IsEnabled = setting.IsEnabled;
        }

        public static RainSensorSettingsView CreateDefault()
        {
            return new RainSensorSettingsView()
            {
                IsEnabled = false,
                RainOffMinDuration = 1440,
                RainStabilitySecTime = 600,
                SensorInputNumber = 0,
                SensorType = RainSensorTypes.NC
            };
        }
    }

}
