using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Admin
{
    public interface IAdminRepository : IDisposable
    {
        bool Test();
   
        #region Setting

        AlertsSetting[] AlertDeviceSettings_Get(string SN);
        bool AlertSettings_Update(string sN, AlertsSetting alertsSetting);

        Models.Device.DeviceSettings Settings_Get(string SN);

        bool DeviceSettings_Update(string SN, Models.Device.DeviceSettings deviceSettings);

        Models.Device.DaySettings[] DaySetting_Get(string SN);

        bool DaySettings_Update(string SN, DaySettings daySettings, List<TimeValueItem> items);

        Models.Device.IrrigatingSettings IrrigatingSettings_Get(string SN);

        bool IrrigatingSettings_Update(string SN, Models.Device.IrrigatingSettings irrigatingSettings);

        Models.Device.DisplaySettings DisplaySettings_Get(string SN);

        bool DisplaySettings_Update(string SN, Models.Device.DisplaySettings displaySettings);

        Models.Device.RainSensorSettings RainSensorSettings_Get(string SN);

        bool RainSensorSettings_Update(string SN, Models.Device.RainSensorSettings rainSensorSettings);

        Models.Device.FlowSensorSettings FlowSensorSettings_Get(string SN);

        bool FlowSensorSettings_Update(string SN, Models.Device.FlowSensorSettings flowSensorSettings);

        bool AlertThresholdSettings_Update(string sN, AlertThresholdSettings alertThresholdSettings);
        AlertThresholdSettings AlertThresholdSettings_Get(string sN);


        #endregion

        #region Device

        bool UpdateDeviceLocation(string SN, string lat, string lon);

        long? AddDevice(string SN, int? ModelID);

        Models.Device.DeviceBase GetDevice(string SN);

        #region Schedule

        bool IrrigationSchedule_Items_Update(string SN, List<Models.Device.IrrigationScheduleItem> items, byte type);

        Models.Device.IrrigationSchedule IrrigationSchedule_GetByDay(string SN, int DayNumber, byte ScheduleType);
        Models.Device.IrrigationSchedule IrrigationSchedule_Get(string SN, byte? ScheduleType);

        Models.Device.IrrigationSchedule IrrigationSchedule_Get_OverStartTime(string SN, byte? ScheduleType);


        bool ScheduleType_Update(string SN, byte ScheduleType);

        byte ScheduleType_Get(string SN);

        //Byte ScheduleType_Get(string SN);

        Models.Device.IrrigationSchedule IrrigationSchedule_GetByZone(string SN, int ZoneNum, Byte? ScheduleType);
        #endregion

        #endregion

        #region Zone


        Models.Zone.ZoneList[] GetDeviceZones(string SN);

        bool ActiveZone_Update(string SN, int ZoneNumber, bool IsEnabled);

        Models.Zone.ZoneList GetZone(string SN, int ZoneNumber);

        Models.Zone.ZoneFlowSensorSettings FlowSensorSettings_Get(string SN, int ZoneNumber);


        bool Zone_FlowSensorSettings_Update(string SN, int ZoneNumber, Models.Zone.ZoneFlowSensorSettings zoneFlowSensorSettings);

        Models.Zone.ZoneIrrigationSuggestion IrrigationSuggestions_Get(string SN, int ZoneNumber);

        bool IrrigationSuggestion_Accept(string SN, int ZoneNumber);

        bool IrrigationSuggestion_Update(string SN, Models.Zone.ZoneIrrigationSuggestion zoneIrrigationSuggestion);

        Models.Zone.ZoneIrrigationSettings ZoneSettings_Get(string SN, int ZoneNumber);

        Models.Zone.ZoneIrrigationAccumulate ZoneIrrigationAccumulate_Get(string SN, int ZoneNumber);

        Models.Zone.Categories[] Categories_Get(string SN, int ZoneNumber);


        bool Zone_UpdateSettings(string SN, int ZoneNumber, Models.Zone.ZoneIrrigationSettings zoneIrrigationSettings);


        bool Categories_Update(string SN, int ZoneNumber, Models.Zone.Categories categories);

        bool Zone_Image_Update(string SN, int ZoneNumber, string url);
       bool Zone_SoakSettings_Update(string sN, int zoneNumber, int? maxCycleTime, int? maxSoakTime);

        bool Zone_Name_Update(string sN, int zoneNumber, string name);
       
        #endregion

        #region Types

        Models.Zone.AdvisorPlantType[] GetPlantTypes();

        Models.Zone.BaseAdvisorOptionalType[] GetSlopeType();

        Models.Zone.BaseAdvisorOptionalType[] GetSoilTypes();

        Models.Zone.AdvisorSprinklerType[] GetSprinklTypes();

        Models.Zone.AdvisorSunExposureType[] GetSunExposureTypes();

        //Models.Zone.Categories GetCategory_ByType(string SN, int ZoneNumber, int Type);

        #endregion
    }
}
