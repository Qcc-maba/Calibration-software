using Nest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.Models;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.ES
{
    public class ESWeatherRepository : Connectors.ElasticsearchLibrary.BaseElasticsearchConnector_2x,
        IWeatherForecastsRepository
    {
        #region CONSTANTS

        public const string ELASTIC__FIELD_LOCATION = "location";
        public const string ELASTIC__TYPE_NAME = "forecasts";
        /// <summary>
        /// Represents the time where record was received/observed by foreacst provider.
        /// </summary>
        public const string ELASTIC__FIELD_DATE_OBSERVED = "recordDateT";




        public const string ELASTIC__DEFAULT_WEATHER_INDEX_NAME = "weatherdata";
        public const string ELASTIC__DEFAULT_WEATHER_DETAILS_INDEX_NAME = "weatherdatadetails";
        public const string ELASTIC__TYPE_WEATHER_DATE_FIELD = "forecastDateT";
        //public const string ELASTIC__TYPE_WEATHER = "forecast";
        // public const string ELASTIC__ROUTING__BY_DEVICE = "sn";
        // public const string ELASTIC__ROUTING__BY_SITE = "siteID";

        #endregion

        #region ctor

        public ESWeatherRepository(WeatherESSettings settings)
            : base(settings)
        {

        }

        #endregion

        #region private methods

        private string _RoutingValue<T>(Models.ForecastDataLog<T> record)
        {
            return Models.ForecastDataLog<T>.HashLocation(record.Location);
        }
        private string _RoutingValue<T>(Location location)
        {
            return Models.ForecastDataLog<T>.HashLocation(location);
        }
        private void _ProccessAfterGet<K>(Models.ForecastDataLog<K> record)
        {
            record.RecordDate = new DateTime((record.RecordDateT * TimeSpan.TicksPerMillisecond) + Connectors.ElasticsearchLibrary.BaseElasticsearchConnector_2x.DATETIME_UNIX_1970_1JAN);
        }

        private void _ProccessBeforePut<K>(Models.ForecastDataLog<K> record)
        {
            record.RecordDateT = (record.RecordDate.Ticks - Connectors.ElasticsearchLibrary.BaseElasticsearchConnector_2x.DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond;
        }

        #endregion

        #region IWeatherForecastsRepository members
        public bool AddWeeklyForecast<T>(ForecastDataLog<T[]> weeklyForecasts)
        {
            var settings = this.CurrentSettings as WeatherESSettings;

            _ProccessBeforePut(weeklyForecasts);
            //index== database , Type== table
            var response = this.IndexRecord(
                                            //index
                                            BuildIndexName(settings.Index_WeeklyIndex_Name, weeklyForecasts.RecordDate),
                                            ELASTIC__TYPE_NAME,
                                            //records
                                            weeklyForecasts,
                                            //modify request,
                                            null,
                                            //id 
                                            weeklyForecasts.ForecastID,
                                           //routing values
                                           _RoutingValue<T>(weeklyForecasts.Location));

            return response != null && response.IsValid;
        }

        public Models.ForecastDataLog<T[]> GetWeeklyForecast<T>(DateTime datetime, Models.Location location)
        {
            return this.GetWeeklyForecasts<T>(datetime, location, 1).FirstOrDefault();
        }

        public Models.ForecastDataLog<T[]>[] GetWeeklyForecasts<T>(DateTime datetime, Models.Location location, int RecordsLimit)
        {
            var settings = this.CurrentSettings as WeatherESSettings;
            var midnight = new DateTime(datetime.Year, datetime.Month, datetime.Day);

            var response = this.Search<Models.ForecastDataLog<T[]>>(
                                            //index
                                            BuildIndexName(settings.Index_WeeklyIndex_Name, datetime),
                                            //type
                                            ELASTIC__TYPE_NAME,
                                            //records modify
                                            (hit, r) =>
                                            {
                                                _ProccessAfterGet(r);

                                                r.DistanceFromForecast = $"{hit.Sorts.First()}KM";
                                            },
                                            //search modify
                                            r =>
                                            {
                                                r.Routing = new string[] { _RoutingValue<T>(location) };
                                                r.Size = RecordsLimit;

                                                this.Search_LocationRange(r, ELASTIC__FIELD_LOCATION,
                                                    //lat
                                                    (double)location.lat,
                                                    //lot
                                                    (double)location.lon,
                                                    //distance
                                                    (double)settings.DistanceKM,
                                                    //units
                                                    DistanceUnit.Kilometers);

                                                //look for records after midnight value. give this search a boost (in order to take the most closer record)
                                                this.Search_BuildRange(r, ELASTIC__FIELD_DATE_OBSERVED, midnight, null);

                                                //sort according to location, then RecordDate
                                                this.Search_Location_SortLocation(r, ELASTIC__FIELD_LOCATION, (double)location.lat, (double)location.lon, DistanceUnit.Kilometers, SortOrder.Ascending);
                                                this.Search_SortColumns(r, $"{ELASTIC__FIELD_DATE_OBSERVED} DESC");
                                            });

            if (response.IsValid && response.Hits != null)
            {
                //since we want to most fresh forecast - so take as DESC - the first item
                return response.Hits
                    .Select(r => r.Source)
                    .ToArray();
            }
            else
            {
                return null;
            }
        }

        public bool AddDailyForecast<T>(ForecastDataLog<T> dailyForecasts)
        {
            var settings = this.CurrentSettings as WeatherESSettings;

            _ProccessBeforePut(dailyForecasts);

            var response = this.IndexRecord(
                                            //index
                                            BuildIndexName(settings.Index_DailyIndex_Name, dailyForecasts.RecordDate),
                                            ELASTIC__TYPE_NAME,
                                            //records
                                            dailyForecasts,
                                            //modify request,
                                            null,
                                            //id 
                                            dailyForecasts.ForecastID,
                                           //routing values
                                           _RoutingValue<T>(dailyForecasts.Location));

            return response != null && response.IsValid;
        }

        public ForecastDataLog<T> GetDailyForecast<T>(DateTime datetime, Location location)
        {
            return this.GetDailyForecasts<T>(datetime, location, 1).FirstOrDefault();
        }

        public ForecastDataLog<T>[] GetDailyForecasts<T>(DateTime datetime, Location location, int RecordsLimit = 5)
        {
            var settings = this.CurrentSettings as WeatherESSettings;
            var midnight = new DateTime(datetime.Year, datetime.Month, datetime.Day);

            var response = this.Search<Models.ForecastDataLog<T>>(
                                            //index
                                            BuildIndexName(settings.Index_DailyIndex_Name, datetime),
                                            //type
                                            ELASTIC__TYPE_NAME,
                                            //records modify
                                            (hit, r) =>
                                            {
                                                _ProccessAfterGet(r);

                                                r.DistanceFromForecast = $"{hit.Sorts.First()}KM";
                                            },
                                            //search modify
                                            r =>
                                            {
                                                r.Routing = new string[] { _RoutingValue<T>(location) };
                                                r.Size = RecordsLimit;

                                                this.Search_LocationRange(r, ELASTIC__FIELD_LOCATION,
                                                    //lat
                                                    (double)location.lat,
                                                    //lot
                                                    (double)location.lon,
                                                    //distance
                                                    (double)settings.DistanceKM,
                                                    //units
                                                    DistanceUnit.Kilometers);

                                                //look for records after midnight value. give this search a boost (in order to take the most closer record)
                                                this.Search_BuildRange(r, ELASTIC__FIELD_DATE_OBSERVED, midnight, null);

                                                //sort according to location, then RecordDate
                                                this.Search_Location_SortLocation(r, ELASTIC__FIELD_LOCATION, (double)location.lat, (double)location.lon, DistanceUnit.Kilometers, SortOrder.Ascending);
                                                this.Search_SortColumns(r, $"{ELASTIC__FIELD_DATE_OBSERVED} DESC");
                                            });

            if (response.IsValid && response.Hits != null)
            {
                //since we want to most fresh forecast - so take as DESC - the first item
                return response.Hits
                    .Select(r => r.Source)
                    .ToArray();
            }
            else
            {
                return null;
            }
        }

        #endregion
    }
}