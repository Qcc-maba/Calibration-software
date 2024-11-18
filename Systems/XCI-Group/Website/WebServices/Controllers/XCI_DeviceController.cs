using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.Controllers
{
    [RoutePrefix("Device")]
    public class XCI_DeviceController : BaseController
    {
        [HttpGet]
        [Route("{SN}")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.DeviceViewWithSettings> GetDevice(string SN)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<BL.ViewModelLayer.Models.Device.DeviceViewWithSettings>(() =>
            {
                var deviceAndSettings = DeviceManager.GetDeviceWithSettings(SN);

                if (deviceAndSettings == null)
                {
                    this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                                                                {
                                                                                     new CommonWebAPI.Models.MessageCodeModel(10,"No such device")
                                                                                },
                                                                                HttpStatusCode.NotFound);
                }

                return deviceAndSettings;
            });
        }

        [HttpPost]
        [Route("{SN}/Settings")]
        public CommonWebAPI.Models.Response UpdateDeviceSettings(string SN, CommonWebAPI.Models.Request<BL.ViewModelLayer.Models.Device.Settings.DeviceSettingsView> request)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceSettings(SN, request.Body));
        }

        [HttpGet]
        [Route("{SN}/Settings")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.Settings.DeviceSettingsView> GetDeviceSettings(string SN)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse(() =>
            {
                var settings = DeviceManager.GetDeviceSettings(SN);

                if (settings == null)
                {
                    this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                                                                {
                                                                                     new CommonWebAPI.Models.MessageCodeModel(10,"No such device")
                                                                                },
                                                                                HttpStatusCode.NotFound);
                }

                return settings;
            });
        }

        [HttpGet]
        [Route("{SN}/DeviceSettings")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.Settings.DeviceSettingsViewBase> GetDeviceSettingsView(string SN)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse(() =>
            {
                var settings = DeviceManager.GetDeviceSettingsBase(SN);

                if (settings == null)
                {
                    this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                                                                {
                                                                                     new CommonWebAPI.Models.MessageCodeModel(10,"No such device")
                                                                                },
                                                                                HttpStatusCode.NotFound);
                }

                return settings;
            });
        }

        [HttpPost]
        [Route("{SN}/DeviceSettings")]
        public CommonWebAPI.Models.Response UpdateDeviceSettingsView(string SN, BL.ViewModelLayer.Models.Device.Settings.DeviceSettingsViewBase setting)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceSettingsView(SN, setting));
        }

        [HttpGet]
        [Route("{SN}/AlertSettings")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.Settings.AlertSettingsView[]> GetAlertSettings(string SN, bool SendDefaults = false)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse(() =>
            {
                var alertSettings = DeviceManager.GetAlertSettings(SN, SendDefaults);

                if (alertSettings == null)
                {
                    this.ThrowHttpResponseException(new CommonWebAPI.Models.MessageCodeModel[]
                                                            {
                                                                                     new CommonWebAPI.Models.MessageCodeModel(10,"No such device")
                                                            },
                                                            HttpStatusCode.NotFound);

                }

                return alertSettings;
            });
        }

        [HttpPost]
        [Route("{SN}/AlertSettings")]
        public CommonWebAPI.Models.Response UpdateAlertSettings(string SN, BL.ViewModelLayer.Models.Device.Settings.AlertSettingsView[] Device_Settings)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateAlertSettings(SN, Device_Settings));
        }

        [HttpPost]
        [Route("{SN}/AlertThresholdSettings")]
        public CommonWebAPI.Models.Response UpdateAlertThresholdSettings(string SN, BL.ViewModelLayer.Models.Device.Settings.AlertThresholdSettingsView setting)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateAlertThresholdSettings(SN, setting));
        }

        #region Schedule

        [HttpGet]
        [Route("{SN}/Schedule")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView> GetIrrigationSchedule(string SN
                                                                                            , byte? SType = null)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse(() => DeviceManager.GetIrrigationSchedule(SN, SType));
        }

        #region Weekly

        //GET -> GetIrrigationSchedule With ScheduleTypes Weekly

        [HttpPost]
        [Route("{SN}/Schedule/Weekly")]
        public CommonWebAPI.Models.Response UapdateDeviceSchedule_Weekly(string SN, BL.ViewModelLayer.Models.Device.Schedule.WeeklyScheduleView WeeklySchedule)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceScheduleWeekly(SN, WeeklySchedule));
        }
        #endregion

        #region Odd

        //GET -> GetIrrigationSchedule With ScheduleTypes Odd

        [HttpPost]
        [Route("{SN}/Schedule/Odd")]
        public CommonWebAPI.Models.Response UapdateDeviceSchedule_OddTyped(string SN, BL.ViewModelLayer.Models.Device.Schedule.DailyScheduleView OddSchedule)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceSchedule_ByDay(SN, OddSchedule, BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Odd));
        }

        #endregion

        #region Even

        //GET -> GetIrrigationSchedule With ScheduleTypes Even

        [HttpPost]
        [Route("{SN}/Schedule/Even")]
        public CommonWebAPI.Models.Response UapdateDeviceSchedule_EvenTyped(string SN, BL.ViewModelLayer.Models.Device.Schedule.DailyScheduleView EvenSchedule)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceSchedule_ByDay(SN, EvenSchedule, BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Even));
        }

        #endregion

        #region By Day

        [HttpGet]
        [Route("{SN}/Schedule/Weekly/{DayNumber}")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.Schedule.DailyScheduleView> GetDevice_WeeklySchedule_ByDay(string SN, byte DayNumber)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<BL.ViewModelLayer.Models.Device.Schedule.DailyScheduleView>(() => DeviceManager.GetDevice_WeeklySchedule_ByDay(SN, DayNumber));
        }

        [HttpPost]
        [Route("{SN}/Schedule/Weekly/{DayNumber}")]
        public CommonWebAPI.Models.Response UpdateDevice_WeeklySchedule_ByDay(string SN, BL.ViewModelLayer.Models.Device.Schedule.DailyScheduleView DailySchedule)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceSchedule_ByDay(SN, DailySchedule, BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Weekly));
        }

        #endregion

        #endregion

        #region DaySetting
        [HttpGet]
        [Route("{SN}/DaySetting")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.Settings.DaySettingViewRespons> GetDaySetting(string SN)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();

            return this.HandleResponse<BL.ViewModelLayer.Models.Device.Settings.DaySettingViewRespons>(() => new BL.ViewModelLayer.Models.Device.Settings.DaySettingViewRespons() { ListDays = DeviceManager.GetDaySettingsView(SN) });
        }


        [HttpPost]
        [Route("{SN}/DaySetting")]
        public CommonWebAPI.Models.Response UpdateDaySetting(string SN, BL.ViewModelLayer.Models.Device.Settings.DaySettingsView[] daysSettingsView)
        {
            RoleModifySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();

            return this.HandleResponse<bool>(() => DeviceManager.UpdateDaySetting(SN, daysSettingsView));
        }

        #endregion


        #region Device -> Zones

        [HttpGet]
        [Route("{SN}/Zones")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.ZoneListView[]> GetDeviceZones(string SN)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();

            return this.HandleResponse<BL.ViewModelLayer.Models.Zone.ZoneListView[]>(() => DeviceManager.GetDeviceZones(SN));
        }


        [HttpPost]
        [Route("{SN}/Zones")]
        public CommonWebAPI.Models.Response UpdateDeviceZones(string SN, BL.ViewModelLayer.Models.Zone.ZoneListView item)
        {
            ViewOnlySN(SN);
            var DeviceManager = CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceZone(SN, item.ZoneNumber, item.IsEnabled));
        }

        #endregion
    }
}