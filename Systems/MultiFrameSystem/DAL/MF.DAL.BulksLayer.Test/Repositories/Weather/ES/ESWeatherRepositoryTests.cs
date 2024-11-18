using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.ES;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.ES
{

    [TestClass()]
    public class MF_DAL_BulksLayer_Weather__ESWeatherRepositoryTests
    {
        #region ctor

        public MF_DAL_BulksLayer_Weather__ESWeatherRepositoryTests()
        {
        }

        #endregion

        #region private methods

        private Models.Location _RandomLocation()
        {
            var rand = new Random();
            var location = new Models.Location()
            {
                lat = rand.Next(0, 75) + (rand.Next(0, 99)/100),
                lon = rand.Next(0, 180) + (rand.Next(0, 99) / 100)
            };

            return location;
        }

        private void CompareDateTimes(DateTime dt1, DateTime dt2)
        {
            Assert.AreEqual(dt1.Year, dt2.Year);
            Assert.AreEqual(dt1.Month, dt2.Month);
            Assert.AreEqual(dt1.Day, dt2.Day);
            Assert.AreEqual(dt1.Hour, dt2.Hour);
            Assert.AreEqual(dt1.Minute, dt2.Minute);
            Assert.AreEqual(dt1.Second, dt2.Second);
            Assert.AreEqual(dt1.Millisecond, dt2.Millisecond);
        }

        private IWeatherForecastsRepository _CreateConnector()
        {
            var settings = new WeatherESSettings()
            {
                Server_URL = @"http://localhost.fiddler:9200"
                //Server_URL = @"http://localhost:9200"

            };
            var connector = new ESWeatherRepository(settings);

            return connector;
        }

        #endregion

        [TestMethod()]
        public void GetWeeklyForecast_Test()
        {
            //covered by AddWeeklyForecasts_Test
            AddWeeklyForecasts_Test();
        }

        [TestMethod()]
        public void AddWeeklyForecast_Test()
        {
            //covered by AddWeeklyForecasts_Test
            AddWeeklyForecasts_Test();
        }

        /// <summary>
        /// Tests "AddWeeklyForecast" and "AddWeeklyForecasts".
        /// </summary>
        [TestMethod()]
        public void AddWeeklyForecasts_Test()
        {
            var connector = _CreateConnector();

            var records = new List<Models.ForecastDataLog<ForecastTestClass[]>>();
            var now = DateTime.UtcNow;
            var randLocation = _RandomLocation();

            #region create records

            int forecastsCount = 15;
            int locationsCount = 10;
            var locations = new Models.Location[locationsCount];
            var forecasts = new Models.ForecastDataLog<ForecastTestClass[]>[locations.Length, forecastsCount];

            //create forecasts on same times for all locations
            for (int locationIndex = 0; locationIndex < locations.Length; locationIndex++)
            {
                //create location
                var location = new Models.Location()
                {
                    lat = randLocation.lat + (locationIndex * 0.2m),
                    lon = randLocation.lon + (locationIndex * 0.2m)
                };
                locations[locationIndex] = location;

                //create forecasts for this location
                for (int forecastIndex = 0; forecastIndex < forecastsCount; forecastIndex++)
                {
                    var r = Models.ForecastDataLog<ForecastTestClass[]>.Create(
                                        now.AddHours(forecastIndex * 3),
                                        location,
                                        new ForecastTestClass[0]);

                    forecasts[locationIndex, forecastIndex] = r;

                    //create days for each forecasts
                    for (int dayIndex = 0; dayIndex < r.ForecastData.Length; dayIndex++)
                    {
                        r.ForecastData[dayIndex] = new ForecastTestClass()
                        {
                            Data1 = $"{forecastIndex}:{dayIndex}",
                            Number1 = dayIndex,
                            ForecastDate = now.AddDays(dayIndex),
                            ForecastDateT = now.AddDays(dayIndex).Ticks
                        };
                    }
                    records.Add(r);
                }
            }

            #endregion

            //add the forecasts
            foreach (var weeklyForecast in records)
            {
                Assert.IsTrue(connector.AddWeeklyForecast(weeklyForecast));
            }

            //wait for all records to be placed correctly
            System.Threading.Thread.Sleep(2500);

            var settings = ((ES.ESWeatherRepository)connector).CurrentSettings as WeatherESSettings;
            settings.DistanceKM = 60;

            for (int locationIndex = 0; locationIndex < locationsCount; locationIndex++)
            {
                var location = locations[locationIndex];

                //we would like to get forecasts more than for this location.
                //we expect to get this location forecasts first (due to the location sorting)
                //and we expect to get the most fresh forecast for this location (which is the last forecast for every location)
                var recordsBack = connector.GetWeeklyForecasts<ForecastTestClass>(now, location, 3 * forecastsCount);
                Assert.IsNotNull(recordsBack);
                //and get as single to make sure it return the last
                var record_single_Back = connector.GetWeeklyForecast<ForecastTestClass>(now, location);
                Assert.IsNotNull(record_single_Back);

                //test the single it's the same as the first in the list
                Assert.AreEqual(recordsBack[0].RecordDate, record_single_Back.RecordDate);
                Assert.AreEqual(recordsBack[0].Location, record_single_Back.Location);
                Assert.AreEqual(recordsBack[0].ForecastID, record_single_Back.ForecastID);
                Assert.AreEqual(recordsBack[0].DistanceFromForecast, record_single_Back.DistanceFromForecast);

                for (int i = 0; i < recordsBack.Length; i++)
                {
                    var forecast = recordsBack[i];
                    if (i == 0)
                    {
                        //make sure we got the forecast for this location as high priority
                        Assert.AreEqual(location, forecast.Location);

                        //the last forecast for each location - it's most fresh one we want!
                        CompareDateTimes(forecasts[locationIndex, forecastsCount - 1].RecordDate, forecast.RecordDate);
                    }
                    else if (i < forecastsCount)
                    {
                        Assert.AreEqual(location, forecast.Location);

                    }
                    else
                    {
                        Assert.AreNotEqual(location, forecast.Location);
                    }
                }
            }
        }

        [TestMethod()]
        public void GetDailyForecast_Test()
        {
            var connector = _CreateConnector();

            var records = new List<Models.ForecastDataLog<ForecastTestClass>>();
            var now = DateTime.UtcNow;
            var randLocation = _RandomLocation();

            #region create records

            int forecastsCount = 15;
            int locationsCount = 10;
            var locations = new Models.Location[locationsCount];
            var forecasts = new Models.ForecastDataLog<ForecastTestClass>[locations.Length, forecastsCount];

            //create forecasts on same times for all locations
            for (int locationIndex = 0; locationIndex < locations.Length; locationIndex++)
            {
                //create location
                var location = new Models.Location()
                {
                    lat = randLocation.lat + (locationIndex * 0.2m),
                    lon = randLocation.lon + (locationIndex * 0.2m)
                };
                locations[locationIndex] = location;

                //create forecasts for this location
                for (int forecastIndex = 0; forecastIndex < forecastsCount; forecastIndex++)
                {
                    var r = Models.ForecastDataLog<ForecastTestClass>.Create(
                                        now.AddHours(forecastIndex * 3),
                                        location,
                                        new ForecastTestClass()
                                        {
                                            Data1 = $"{forecastIndex}",
                                            Number1 = forecastIndex,
                                            ForecastDate = now.AddDays(forecastIndex),
                                            ForecastDateT = now.AddDays(forecastIndex).Ticks
                                        });

                    forecasts[locationIndex, forecastIndex] = r;

                    records.Add(r);
                }
            }

            #endregion

            //add the forecasts
            foreach (var dailyForecast in records)
            {
                Assert.IsTrue(connector.AddDailyForecast(dailyForecast));
            }

            //wait for all records to be placed correctly
            System.Threading.Thread.Sleep(2500);

            var settings = ((ES.ESWeatherRepository)connector).CurrentSettings as WeatherESSettings;
            settings.DistanceKM = 60;

            for (int locationIndex = 0; locationIndex < locationsCount; locationIndex++)
            {
                var location = locations[locationIndex];

                //we would like to get forecasts more than for this location.
                //we expect to get this location forecasts first (due to the location sorting)
                //and we expect to get the most fresh forecast for this location (which is the last forecast for every location)
                var recordsBack = connector.GetDailyForecasts<ForecastTestClass>(now, location, 3 * forecastsCount);
                Assert.IsNotNull(recordsBack);
                //and get as single to make sure it return the last
                var record_single_Back = connector.GetDailyForecast<ForecastTestClass>(now, location);
                Assert.IsNotNull(record_single_Back);

                //test the single it's the same as the first in the list
                Assert.AreEqual(recordsBack[0].RecordDate, record_single_Back.RecordDate);
                Assert.AreEqual(recordsBack[0].Location, record_single_Back.Location);
                Assert.AreEqual(recordsBack[0].ForecastID, record_single_Back.ForecastID);
                Assert.AreEqual(recordsBack[0].DistanceFromForecast, record_single_Back.DistanceFromForecast);

                for (int i = 0; i < recordsBack.Length; i++)
                {
                    var forecast = recordsBack[i];
                    if (i == 0)
                    {
                        //make sure we got the forecast for this location as high priority
                        Assert.AreEqual(location, forecast.Location);

                        //the last forecast for each location - it's most fresh one we want!
                        CompareDateTimes(forecasts[locationIndex, forecastsCount - 1].RecordDate, forecast.RecordDate);
                    }
                    else if (i < forecastsCount)
                    {
                        Assert.AreEqual(location, forecast.Location);

                    }
                    else
                    {
                        Assert.AreNotEqual(location, forecast.Location);
                    }
                }
            }
        }

        [TestMethod()]
        public void AddDailyForecast_Test()
        {
            //covered by GetDailyForecast_Test
            GetDailyForecast_Test();
        }
    }
}