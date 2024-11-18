
using Microsoft.Owin.Security;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Web.Http;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;
using ViewModelLayer = Maba.Hydra2.Systems.MF.BL.ViewModelLayer;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather;
using Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.ES;
using Maba.Connectors.WeatherServices;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers
{
    [RoutePrefix("Weather")]
    [Authorize]
    public class WeatherController : BaseController
    {
        #region Weather Forecasts

        [HttpGet]
        [Route("{SiteID}/WeeklyForecast")]
        public CommonWebAPI.Models.Response<ForecastDataLogView> GetWeeklyForecast(long dateTicks, long SiteID)
        {
            var siteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            var site = siteManager.GetSite(CurrentUser.UserID, SiteID);

            var tempUnit = this.GetIdentity().GetUserTemperatureUnit() == "C" ? ThreeUnitsView.TemperatureUnits.Celsius : ThreeUnitsView.TemperatureUnits.Fahrenheit;

            var WeatherManager = CreateMFManager<WeatherViewModelManager>();
            return this.HandleResponse<ForecastDataLogView>(() => WeatherManager.GetWeeklyForecast(
                                                                                            tempUnit,
                                                                                            GetTimeHelper.ToDateTime_Milliseconds(dateTicks),
                                                                                            site.Location.MapCenter.Latitude,
                                                                                            site.Location.MapCenter.Longitude));
        }

        [HttpGet]
        [Route("Device/{SN}/WeeklyForecast")]
        public CommonWebAPI.Models.Response<ForecastDataLogView> GetWeeklyForecast(long dateTicks, string SN)
        {
            var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
            var device = DeviceManager.GetDevice(this.CurrentUser.UserID, SN);

            var tempUnit = this.GetIdentity().GetUserTemperatureUnit() == "C" ? ThreeUnitsView.TemperatureUnits.Celsius : ThreeUnitsView.TemperatureUnits.Fahrenheit;

            var WeatherManager = CreateMFManager<WeatherViewModelManager>();
            return this.HandleResponse<ForecastDataLogView>(() => WeatherManager.GetWeeklyForecast(
                                                                                            tempUnit, 
                                                                                            GetTimeHelper.ToDateTime_Milliseconds(dateTicks),
                                                                                            device.Location.Latitude,
                                                                                            device.Location.Longitude));
        }

        [HttpGet]
        [Route("{SiteID}/DailyForecast")]
        public CommonWebAPI.Models.Response<ForecastDataLogView> GetDailyForecast(long dateTicks, long SiteID)
        {
            var siteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            var site = siteManager.GetSite(CurrentUser.UserID, SiteID);

            var tempUnit = this.GetIdentity().GetUserTemperatureUnit() == "C" ? ThreeUnitsView.TemperatureUnits.Celsius : ThreeUnitsView.TemperatureUnits.Fahrenheit;

            var WeatherManager = CreateMFManager<WeatherViewModelManager>();
            return this.HandleResponse<ForecastDataLogView>(() => WeatherManager.GetDailyForecast(
                                                                                            tempUnit, 
                                                                                            GetTimeHelper.ToDateTime_Milliseconds(dateTicks),
                                                                                            site.Location.MapCenter.Latitude,
                                                                                            site.Location.MapCenter.Longitude));
        }

        [HttpGet]
        [Route("Device/{SN}/DailyForecast")]
        public CommonWebAPI.Models.Response<ForecastDataLogView> GetDailyForecast(long dateTicks, string SN)
        {
            var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
            var device = DeviceManager.GetDevice(this.CurrentUser.UserID, SN);

            var tempUnit = this.GetIdentity().GetUserTemperatureUnit() == "C" ? ThreeUnitsView.TemperatureUnits.Celsius : ThreeUnitsView.TemperatureUnits.Fahrenheit;

            var WeatherManager = CreateMFManager<WeatherViewModelManager>();
            return this.HandleResponse<ForecastDataLogView>(() => WeatherManager.GetDailyForecast(
                                                                                            tempUnit, 
                                                                                            GetTimeHelper.ToDateTime_Milliseconds(dateTicks),
                                                                                            device.Location.Latitude,
                                                                                            device.Location.Longitude));
        }

        [HttpGet]
        [Route("{SiteID}/Setting")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Weather.BaseWaterAlgorithmView> GetWeatherSavingSettingsView(long SiteID)
        {
            var WeatherManager = CreateMFManager<ViewModelLayer.Models.Weather.WeatherViewModelManager>();
            var userTemperatureUnit = this.GetIdentity().GetUserTemperatureUnit();

            var body = WeatherManager.GetWeatherSavingSettingsView(CurrentUser.UserID, userTemperatureUnit, SiteID);

            return new CommonWebAPI.Models.Response<ViewModelLayer.Models.Weather.BaseWaterAlgorithmView>()
            {
                Body = body,
                Result = body != null
            };
        }

        [HttpGet]
        [Route("Device/{SN}/Setting")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Weather.BaseWaterAlgorithmView> GetWeatherSavingSettingsView(string SN)
        {
            var WeatherManager = CreateMFManager<ViewModelLayer.Models.Weather.WeatherViewModelManager>();

            var userTemperatureUnit = this.GetIdentity().GetUserTemperatureUnit();

            var body = WeatherManager.GetWeatherSavingSettingsView(CurrentUser.UserID, userTemperatureUnit, SN);

            return new CommonWebAPI.Models.Response<ViewModelLayer.Models.Weather.BaseWaterAlgorithmView>()
            {
                Body = body,
                Result = body != null
            };
        }

        [HttpPost]
        [Route("{SiteID}/Setting")]
        public CommonWebAPI.Models.Response SaveWeatherSavingSettingsView(long SiteID, bool AsDefaultValuesOnly, ViewModelLayer.Models.Weather.WaterAlgorithm_P1SettingsView settings)
        {
            var WeatherManager = CreateMFManager<ViewModelLayer.Models.Weather.WeatherViewModelManager>();

            return new CommonWebAPI.Models.Response()
            {
                Result = WeatherManager.UpdateSiteWeatherAlgorithm_P1(CurrentUser.UserID, SiteID, settings, AsDefaultValuesOnly),
            };
        }

        [HttpPost]
        [Route("Device/{SN}/Setting")]
        public CommonWebAPI.Models.Response SaveWeatherSavingSettingsView(string SN, ViewModelLayer.Models.Weather.WaterAlgorithm_P1SettingsView settings)
        {
            var WeatherManager = CreateMFManager<ViewModelLayer.Models.Weather.WeatherViewModelManager>();

            return new CommonWebAPI.Models.Response()
            {
                Result = WeatherManager.UpdateSiteWeatherAlgorithm_P1(CurrentUser.UserID, SN, settings)
            };
        }

        #endregion
    }
}

