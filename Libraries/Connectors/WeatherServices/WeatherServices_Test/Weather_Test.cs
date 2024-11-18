using System;
using System.Collections;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Connectors.WeatherServices.Providers;

namespace Maba.Connectors.WeatherServices.Testing
{
    [TestClass]
    public class Weather_Test
    {
        private string Icons_URL = "http://www.myserver.com/images";

        private Settings.ForecastWeatherSettings _CreateProviderSettings()
        {            
            var settings = new Settings.ForecastWeatherSettings()
            {
                WProviders = new Settings.ProviderSetting[]
                 {
                     new Settings.ProviderSetting()
                     {
                          Key="4a9389f8e54f099c",
                          ProviderName=Providers.Wunderground.PROVIDER_NAME,
                          Icons_URL= Icons_URL
                     },
                     new Settings.ProviderSetting()
                     {
                          Key="22a8ee789d202b92d531654126a76e68",
                          ProviderName=Providers.Wunderground_v2.PROVIDER_NAME,
                          Icons_URL= Icons_URL
                     },
                     new Settings.ProviderSetting()
                     {
                          Key="52bfe99737cd7f334b45b74cc6137393",
                          ProviderName=Providers.Forecast.PROVIDER_NAME,
                          Icons_URL= Icons_URL
                     }
                 }
            };

            return settings;
        }

        #region private methods

        private void WeatherProvider_Generic<T>(string ProviderName) where T : IWeatherProvider
        {
            var settings = _CreateProviderSettings();
            //get/create settings
            var providers = Settings.ForecastWeatherSettings.GetSupportedProviders();
            Assert.IsNotNull(providers);
            var providerSettings = settings.WProviders.FirstOrDefault(p => p.ProviderName == ProviderName);
            Assert.IsNotNull(providerSettings);

            var provider = Activator.CreateInstance(typeof(T), new object[] { providerSettings }) as IWeatherProvider;

            var supportedUnits = provider.GetSupportedUnits();

            foreach (var unit in supportedUnits)
            {
                for (int forecastDays = 1; forecastDays <= 7; forecastDays++)
                {
                    var forecast = provider.GetForecast((decimal)32.5333, (decimal)35.53333, forecastDays, unit);
                    Assert.IsNotNull(forecast);
                    Assert.AreEqual(forecastDays, forecast.forecastList.Length);

                    int dayRunning = (int)DateTime.UtcNow.DayOfWeek;
                    int dayIndex = 0;
                    foreach (var day in forecast.forecastList.OrderBy(d => d.date.Day))
                    {
                        Assert.IsNotNull(day);
                        #region test temp

                        Assert.IsNotNull(day.Temp_Fahrenheit);
                        Assert.IsNotNull(day.Temp_Celsius);

                        //Avg
                        Assert.AreEqual(day.Temp_Fahrenheit.Avg.HasValue, day.Temp_Celsius.Avg.HasValue);
                        if (day.Temp_Fahrenheit.Avg.HasValue)
                        {
                            Assert.IsTrue(Math.Abs(day.Temp_Fahrenheit.Avg.Value - ((day.Temp_Celsius.Avg.Value * 1.8m) + 32)) <= 0.5m);
                        }

                        //High 
                        Assert.AreEqual(day.Temp_Fahrenheit.Max.HasValue, day.Temp_Celsius.Max.HasValue);
                        if (day.Temp_Fahrenheit.Max.HasValue)
                        {
                            Assert.IsTrue(Math.Abs(day.Temp_Fahrenheit.Max.Value - ((day.Temp_Celsius.Max.Value * 1.8m) + 32)) <= 0.5m);
                        }

                        //Low
                        Assert.AreEqual(day.Temp_Fahrenheit.Min.HasValue, day.Temp_Celsius.Min.HasValue);
                        if (day.Temp_Fahrenheit.Min.HasValue)
                        {
                            Assert.IsTrue(Math.Abs(day.Temp_Fahrenheit.Min.Value - ((day.Temp_Celsius.Min.Value * 1.8m) + 32)) <= 0.5m);
                        }

                        #endregion

                        var dayBefore = ((dayRunning + dayIndex - 1) % 7) == (int)day.date.DayOfWeek;
                        var daySame = ((dayRunning + dayIndex) % 7) == (int)day.date.DayOfWeek;
                        var dayAfter = ((1 + dayRunning + dayIndex) % 7) == (int)day.date.DayOfWeek;

                        Assert.IsTrue(dayBefore || daySame || dayAfter);
                        dayIndex++;
                    }
                }
            }
        }

        #endregion


        [TestMethod]
        public void WeatherProvider_Wunderground()
        {
            WeatherProvider_Generic<Providers.Wunderground>(Providers.Wunderground.PROVIDER_NAME);
        }

        [TestMethod]
        public void WeatherProvider_Wunderground2()
        {
            WeatherProvider_Generic<Providers.Wunderground_v2>(Providers.Wunderground_v2.PROVIDER_NAME);
        }

        [TestMethod]
        public void WeatherProvider_Forecast()
        {
            WeatherProvider_Generic<Providers.Forecast>(Providers.Forecast.PROVIDER_NAME);
        }


        [TestMethod]
        public void WeatherProvider_Wunderground2_get()
        {
            var providers = _CreateProviderSettings();

            var providerSettings = providers.WProviders.FirstOrDefault(p => p.ProviderName == Providers.Wunderground_v2.PROVIDER_NAME);
            Assert.IsNotNull(providerSettings);
            Wunderground_v2 provider = new Wunderground_v2(providerSettings);
            var item = provider.GetHistorical((decimal)32.5333, (decimal)35.53333, DateTime.Now.AddDays(-20), DateTime.Now, "e");
            Assert.IsTrue(item.IsValid);
        }

        [TestMethod]
        public void WeatherProvider_Wunderground2_CurrentObservations()
        {
            var providers = _CreateProviderSettings();

            var providerSettings = providers.WProviders.FirstOrDefault(p => p.ProviderName == Providers.Wunderground_v2.PROVIDER_NAME);
            Assert.IsNotNull(providerSettings);
            Wunderground_v2 provider = new Wunderground_v2(providerSettings);
            var item =  provider.GetCurrentObservations((decimal)32.5333, (decimal)35.53333, "e");
            Assert.IsTrue(item.IsValid);
        }
    }
}
