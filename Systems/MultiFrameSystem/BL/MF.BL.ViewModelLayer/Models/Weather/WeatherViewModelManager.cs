using Maba.Connectors.WeatherServices.Providers;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;
using Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Forecast = Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather
{
    public class WeatherViewModelManager : Base.BaseViewModelManager
    {
        #region members

        private DAL.AdminLayer.Repositories.Weather.IWeatherRepository _WeatherRepository = null;
        private DAL.BulksLayer.Repositories.Weather.IWeatherForecastsRepository _WeatherForecastsRepository = null;

        #endregion

        #region ctor

        public WeatherViewModelManager(Base.ViewModelSettings currentSettings)
            : base(currentSettings)
        {
            _WeatherRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IWeatherRepository();
            _WeatherForecastsRepository = currentSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IWeatherForecastsRepository();

        }

        #endregion

        #region private methods

        private BaseWaterAlgorithmView GetSpecificAlgorithm(DAL.AdminLayer.Repositories.Weather.BaseWeatherAlgorithm algorithm, string TemperatureUnit)
        {
            BaseWaterAlgorithmView algorithmView = null;

            switch (algorithm == null ? (int?)null : algorithm.WeatherAlgorithmTypeID)
            {
                case null:
                case Models.Weather.WaterAlgorithm_P1SettingsView.TypeID:
                    WaterAlgorithm_P1SettingsView algorithm_p1 = null;
                    if (algorithm == null)
                    {
                        algorithm_p1 = new WaterAlgorithm_P1SettingsView()
                        {
                            IsEnabled = true,
                            ChangeHumidity_Per5Precent = -10,
                            ChangeTemp_Per5Deg = 20,
                            HottestMonthTemp = 40,
                            NormalHumidity = 50,
                            PreciptationTreshold = 75,
                            ManualValues = false,
                            TemperatureUnit = "C"
                        };
                    }
                    else
                    {
                        var DAL_algorithm_p1 = _WeatherRepository.WeatherAlgorithm_P1_Get(algorithm.WeatherAlgorithmID);
                        algorithm_p1 = new WaterAlgorithm_P1SettingsView(DAL_algorithm_p1);
                    }

                    algorithm_p1.ConvertTempUnit(TemperatureUnit);
                    algorithmView = algorithm_p1;
                    break;
            }

            return algorithmView;
        }

        #endregion

        #region Forecast methods (location based)

        public ForecastDataLogView GetWeeklyForecast(ThreeUnitsView.TemperatureUnits Unit, DateTime date, decimal lat, decimal lon)
        {
            var location = new Location()
            {
                lat = lat,
                lon = lon
            };

            var cachedForecast = _WeatherForecastsRepository.GetWeeklyForecast<ForecastDataView>(date, location);

            if (cachedForecast == null
                || cachedForecast.ForecastData == null
                || cachedForecast.ForecastData.Length == 0
                || cachedForecast.ForecastData.Any(f => f.Version != ForecastDataView.LAST_VERSION)
                || (date - cachedForecast.RecordDate).TotalDays >= 1)
            {
                date = DateTime.UtcNow;

                //get fresh forecast
                var weatherConnector = this.CurrentSettings.Get_WeatherConnector();
                var forecast = weatherConnector.GetForecast(lat, lon, 7, null);

                //convert to view
                var forecastDay = forecast.forecastList
                    .Select(f => new ForecastDataView(Unit, f, date))
                    .ToArray();

                //create forecasts objects
                var freshForecasts = ForecastDataLog<ForecastDataView[]>.Create(
                                                        DateTime.UtcNow,
                                                        new Location() { lat = forecast.location.lat, lon = forecast.location.lon },
                                                        forecastDay);
                foreach (var f in freshForecasts.ForecastData)
                {
                    f.Version = ForecastDataView.LAST_VERSION;
                }
                _WeatherForecastsRepository.AddWeeklyForecast(freshForecasts);

                return new ForecastDataLogView(freshForecasts);
            }
            else
            {
                return new ForecastDataLogView(cachedForecast)
                {
                    Cached = true
                };
            }

        }

        public ForecastDataLogView GetDailyForecast(ThreeUnitsView.TemperatureUnits Unit, DateTime date, decimal lat, decimal lon)
        {
            var location = new Location()
            {
                lat = lat,
                lon = lon
            };

            var cachedForecast = _WeatherForecastsRepository.GetDailyForecast<ForecastDataView>(date, location);

            if (cachedForecast == null
                || cachedForecast.ForecastData == null
                || cachedForecast.ForecastData.Version != ForecastDataView.LAST_VERSION
                || (date - cachedForecast.RecordDate).TotalDays >= 1)
            {
                date = DateTime.UtcNow;

                //get fresh forecast (weekly)
                var weatherConnector = this.CurrentSettings.Get_WeatherConnector();
                var forecast = weatherConnector.GetForecast(lat, lon, 7, null);

                //convert to view
                var forecastDay = forecast.forecastList
                    .Select(f => new ForecastDataView(Unit, f, date))
                    .ToArray();

                //create forecasts objects
                var freshForecasts = ForecastDataLog<ForecastDataView[]>.Create(
                                                        forecast.forecastList[0].date,
                                                        new Location() { lat = forecast.location.lat, lon = forecast.location.lon },
                                                        forecastDay);

                foreach (var f in freshForecasts.ForecastData)
                {
                    f.Version = ForecastDataView.LAST_VERSION;
                }

                var dailyForecast = new ForecastDataLog<ForecastDataView>()
                {
                    DistanceFromForecast = freshForecasts.DistanceFromForecast,
                    ForecastData = freshForecasts.ForecastData[0],
                    Location = freshForecasts.Location,
                    RecordDate = freshForecasts.RecordDate
                };

                _WeatherForecastsRepository.AddWeeklyForecast(freshForecasts);
                _WeatherForecastsRepository.AddDailyForecast(dailyForecast);

                //return as daily
                return new ForecastDataLogView()
                {
                    ForecastsData = new ForecastDataView[] { dailyForecast.ForecastData },
                    Location = new LocationView() { lat = forecast.location.lat, lon = forecast.location.lon },
                    RecordDate = freshForecasts.RecordDate
                };
            }
            else
            {
                return new ForecastDataLogView(cachedForecast)
                {
                    Cached = true
                };
            }
        }

        #endregion

        #region settings methods (Site)

        public BaseWaterAlgorithmView GetWeatherSavingSettingsView(long UserID, string TemperatureUnit, long SiteID)
        {
            ValidateOwnership_Site(UserID, SiteID);

            var algorithm = _WeatherRepository.WeatherAlgorithm_Get(SiteID);

            return GetSpecificAlgorithm(algorithm, TemperatureUnit);
        }

        public bool UpdateSiteWeatherAlgorithm_P1(long UserID, long SiteID, Weather.WaterAlgorithm_P1SettingsView weatherAlgorithm_P1, bool AsDefaultValuesOnly)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleModify(data);

            //add it as new algorithm
            var algorithmDAL = weatherAlgorithm_P1.To_DAL();
            _WeatherRepository.WeatherAlgorithm_P1_Add(algorithmDAL);

            //update to site
            _WeatherRepository.WeatherAlgorithm_UpdateSite(AsDefaultValuesOnly, UserID, SiteID, algorithmDAL.AlgorithmID);

            return true;
        }

        #endregion

        #region settings methods (Device)

        public BaseWaterAlgorithmView GetWeatherSavingSettingsView(long UserID, string TemperatureUnit, string SN)
        {
            Validate_RoleView(ValidateOwnership_SN(UserID, SN));

            var algorithm = _WeatherRepository.WeatherAlgorithm_Get(SN);
            return GetSpecificAlgorithm(algorithm, TemperatureUnit);
        }

        public bool UpdateSiteWeatherAlgorithm_P1(long UserID, string SN, Weather.WaterAlgorithm_P1SettingsView weatherAlgorithm_P1)
        {
            Validate_RoleModify(ValidateOwnership_SN(UserID, SN));

            //add it as new algorithm
            var algorithmDAL = weatherAlgorithm_P1.To_DAL();
            _WeatherRepository.WeatherAlgorithm_P1_Add(algorithmDAL);

            return _WeatherRepository.WeatherAlgorithm_Update(SN, algorithmDAL.AlgorithmID);
        }

        #endregion

        #region BaseViewModelManager members

        protected override void OnDispose()
        {
            if (_WeatherRepository != null)
            {
                this._WeatherRepository.Dispose();
            }

            if (_WeatherForecastsRepository != null)
            {
                this._WeatherForecastsRepository.Dispose();
            }
        }

        #endregion
    }
}

