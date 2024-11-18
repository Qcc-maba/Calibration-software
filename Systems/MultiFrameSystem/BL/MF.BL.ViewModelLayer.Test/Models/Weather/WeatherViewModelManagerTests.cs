using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.WeatherServices.Settings;
using Maba.Connectors.WeatherServices.Providers;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather.Test
{
    [TestClass()]
    public class WeatherViewModelManagerTests
    {
        public static Random rand = new Random();

        #region ctor

        public WeatherViewModelManagerTests()
        {

        }

        #endregion

        #region private methods

        private WeatherViewModelManager _CreateManager()
        {
            var settings = new Base.ViewModelSettings()
            {
                Weather_Settings = new ForecastWeatherSettings()
                {
                    WProviders = new ProviderSetting[]
                     {
                        new ProviderSetting()
                        {
                          Key="22a8ee789d202b92d531654126a76e68",
                          ProviderName=Wunderground_v2.PROVIDER_NAME,
                          Icons_URL= ""
                        }
                     }
                },
                WeatherRepositorySettings_ES = new DAL.BulksLayer.Repositories.Weather.ES.WeatherESSettings()
                {
                    Server_URL = @"http://localhost.fiddler:9200"
                }
            };

            #region repositories settings

            settings.DAL_AdminLayer_RepositoriesGenerator = new DAL.AdminLayer.Repositories.RepositoryGenerator()
            {
                Generator_IAccountRepository = () => new DAL.AdminLayer.Repositories.Account.TSQL.TSQLAccountRepository(),
                Generator_IDeviceProcessingRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository(),
                Generator_IDeviceRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceRepository(),
                Generator_IFolderingRepository = () => new DAL.AdminLayer.Repositories.Foldering.TSQL.TSQLFolderingRepository(),
                Generator_IWeatherRepository = () => new DAL.AdminLayer.Repositories.Weather.TSQL.TSQLIWeatherRepository()
            };

            settings.DAL_BulksLayer_RepositoriesGenerator = new DAL.BulksLayer.Repositories.RepositoryGenerator()
            {
                Generator_IWeatherForecastsRepository = () => new DAL.BulksLayer.Repositories.Weather.ES.ESWeatherRepository(settings.WeatherRepositorySettings_ES ?? new DAL.BulksLayer.Repositories.Weather.ES.WeatherESSettings())
            };

            #endregion

            var manager = new WeatherViewModelManager(settings);

            return manager;
        }

        #endregion

        [TestMethod()]
        public void GetWeeklyForecast_Test()
        {
            var manager = _CreateManager();

            var lat = rand.Next(0, 32) + rand.Next(0, 32) / 100m;
            var lon = rand.Next(0, 32) + rand.Next(0, 32) / 100m;

            var weekly = manager.GetWeeklyForecast(ThreeUnitsView.TemperatureUnits.Celsius, DateTime.UtcNow, lat, lon);
            Assert.IsNotNull(weekly);
            Assert.IsFalse(weekly.Cached);
            Assert.IsNotNull(weekly.ForecastsData);
            Assert.AreEqual(7, weekly.ForecastsData.Length);

            System.Threading.Thread.Sleep(1000);

            var weekly2 = manager.GetWeeklyForecast(ThreeUnitsView.TemperatureUnits.Celsius, DateTime.UtcNow, lat, lon);
            Assert.IsTrue(weekly2.Cached);
        }

        [TestMethod()]
        public void GetDailyForecast_Test()
        {
            var manager = _CreateManager();

            var lat = rand.Next(0, 32) + rand.Next(0, 32) / 100m;
            var lon = rand.Next(0, 32) + rand.Next(0, 32) / 100m;


            var daily1 = manager.GetDailyForecast(ThreeUnitsView.TemperatureUnits.Celsius, DateTime.UtcNow, lat, lon);
            Assert.IsNotNull(daily1);
            Assert.IsFalse(daily1.Cached);
            Assert.IsNotNull(daily1.ForecastsData);
            Assert.AreEqual(1, daily1.ForecastsData.Length);

            System.Threading.Thread.Sleep(1000);

            var daily2 = manager.GetDailyForecast(ThreeUnitsView.TemperatureUnits.Celsius, DateTime.UtcNow, lat, lon);
            Assert.IsTrue(daily2.Cached);
        }

        [TestMethod()]
        public void GetSiteWeatherView_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void UpdateSiteWeatherAlgorithm_P1_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void GetSiteWeatherView_Test1()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void UpdateSiteWeatherSetting_Test()
        {
            Assert.Fail();
        }
    }
}