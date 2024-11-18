using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Configuration;
using System.Xml.Serialization;

namespace Maba.Connectors.WeatherServices.Settings
{
    public class ForecastWeatherSettings
    {
        public ProviderSetting[] WProviders { get; set; }

        #region ctor

        public ForecastWeatherSettings()
        {
            WProviders = new ProviderSetting[]
            {
                  new ProviderSetting()
                  {
                        Icons_URL ="",
                        Key=null,
                        ProviderName=""
                  }
            };
        }

        #endregion

        #region public static

        public static string[] GetSupportedProviders()
        {
            //var icons_URL = @"https://s3-us-west-1.amazonaws.com/Maba-website/Weather/{0}";

            return new string[]
            {
                Providers.Wunderground_v2.PROVIDER_NAME,
                Providers.Wunderground.PROVIDER_NAME,
                Providers.Forecast.PROVIDER_NAME
            };
        }


        public static Providers.IWeatherProviderHistorical GetHistoricalProvider(ProviderSetting P)
        {
            return new WeatherServices.Providers.Wunderground_v2(P);
        }

        public static IWeatherProvider GetProvider(ProviderSetting P)
        {
            switch (P.ProviderName)
            {
                case WeatherServices.Providers.Wunderground.PROVIDER_NAME:
                    return new WeatherServices.Providers.Wunderground(P);
                case WeatherServices.Providers.Wunderground_v2.PROVIDER_NAME:
                    return new WeatherServices.Providers.Wunderground_v2(P);
                case WeatherServices.Providers.Forecast.PROVIDER_NAME:
                    return new WeatherServices.Providers.Forecast(P);
            }

            return null;
        }

        #endregion

        public IWeatherProvider GetPrefferedProvider()
        {
            IWeatherProvider p = null;

            for (int i = 0; i < WProviders.Length; i++)
            {
                if (WProviders[i] != null && !String.IsNullOrEmpty(WProviders[i].Key))
                {
                    p = GetProvider(WProviders[i]);
                    if (p != null && !String.IsNullOrEmpty(p.ProviderName))
                    {
                        return p;
                    }
                }
            }

            return null;
        }
    }
}

//***
// old url : http://api.wunderground.com/api/{0}/forecast10day/q/{1},{2}.json
//old key : 4a9389f8e54f099c

//new url : @"http://api.weather.com/v1/geocode/{0}/{1}/forecast/daily/3day.json?apiKey={2}"
//http://api.weather.com/v1/geocode/34.063/-84.217/forecast/daily/10day.json?apiKey=22a8ee789d202b92d531654126a76e68&language=en-US&units=e
//new key : 22a8ee789d202b92d531654126a76e68
//***//
