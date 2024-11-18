namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class DeviceSettingsView
    {
        public DeviceSettingsViewBase DeviceSettings { get; set; }
        public IrrigatingSettingsView IrrigatingSettings { get; set; }
        public DisplaySettingsView DisplaySettings { get; set; }
        public RainSensorSettingsView RainSensorSettings { get; set; }
        public FlowSensorSettingsView FlowSensorSettings { get; set; }

        public AlertThresholdSettingsView AlertThresholdSettings { get; set; }
        public Schedule.BaseDeviceScheduleView IrrigationSchedule { get; set; }
        public DeviceAllAlertsSettingsView DeviceAlertsSettings { get; set; }
    }
}
