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
    public class DisplaySettingsView
    {
        public int DisplayCharset { set; get; }
        public enum TemperatureTypes
        {
            Fahrenheit = 1,
            Cellcius = 2
        }
        public enum ClockTypes
        {
            AM_PM = 1,
            Hours24 = 2
        }

        [JsonConverter(typeof(StringEnumConverter))]
        public ClockTypes ClockType { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public TemperatureTypes TemperatureType { get; set; }

        public DisplaySettingsView()
        {
                
        }

        public DisplaySettingsView(DisplaySettings Settings)
        {
            if (Settings == null)
                return;
            TemperatureType =( TemperatureTypes) Settings.TemperatureType;
            ClockType = (ClockTypes)Settings.ClockType;
            DisplayCharset = Settings.DisplayCharset;
        }

        public static DisplaySettingsView CreateDefault()
        {
            return new DisplaySettingsView()
            {
                ClockType = ClockTypes.Hours24,
                DisplayCharset = 0,
                TemperatureType = TemperatureTypes.Cellcius
            };
                 
        }
    }
}
