using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class ZoneIrrigationSettingsView
    {
        //[JsonConverter(typeof(Newtonsoft.Json.Converters.HexConvertor))]
        public string WireColor { get; set; }

        public bool IsEnabled { get; set; }

        /// <summary>
        /// (%Percent)
        /// </summary>
        public int IrrigationFactor { get; set; }

        public bool UserWeatherSavingAlgorithm { get; set; }

        public ZoneIrrigationSettingsView()
        {

        }

        public ZoneIrrigationSettingsView(ZoneIrrigationSettings irrigatingSettings)
        {
            if (irrigatingSettings == null)
                return;
            WireColor = irrigatingSettings.WireColor;
            IrrigationFactor = irrigatingSettings.IrrigationFactor;
            UserWeatherSavingAlgorithm = irrigatingSettings.UserWeatherAlgorithm;
            IsEnabled = irrigatingSettings.IsEnabled;
        }

        public static ZoneIrrigationSettingsView CreateDefault()
        {
            return new ZoneIrrigationSettingsView()
            {
                IsEnabled = true,
                IrrigationFactor = 100,
                UserWeatherSavingAlgorithm = true,
                WireColor = ""
            };
        }
    }
}
