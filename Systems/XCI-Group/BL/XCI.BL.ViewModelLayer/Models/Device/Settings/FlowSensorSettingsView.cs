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
    public class FlowSensorSettingsView
    {
        public enum FlowSensorTypes
        {
            Pulse = 1,
            DI = 2
        }

        [JsonConverter(typeof(StringEnumConverter))]
        public FlowSensorTypes SensorType { get; set; }

        public bool IsEnabled { get; set; }
        public int? SensorInputNumber { get; set; }

        public decimal PulseSize { get; set; }
        public int PulseType { get; set; }

        public decimal DI_KValue { get; set; }
        public decimal DI_OffsetValue { get; set; }

        public FlowSensorSettingsView(FlowSensorSettings setting)
        {
            if (setting == null)
                return;
            IsEnabled = setting.IsEnabled;
            SensorInputNumber = setting.SensorInputNumber;
            PulseSize = setting.Pulse_PulseSize;
            PulseType = setting.Pulse_PulseType;
            DI_KValue = setting.DI_KValue;
            DI_OffsetValue = setting.DI_OffsetValue;
            SensorType = setting.SensorType == 1 ? FlowSensorTypes.Pulse : FlowSensorTypes.DI;
        }

        public FlowSensorSettingsView()
        {

        }
        public static FlowSensorSettingsView CreateDefault()
        {
            return new FlowSensorSettingsView()
            {
                IsEnabled = false,
                SensorType = FlowSensorTypes.Pulse,
                PulseSize = 100,
                PulseType = 1,
                SensorInputNumber = 0
            };
        }
    }
}
