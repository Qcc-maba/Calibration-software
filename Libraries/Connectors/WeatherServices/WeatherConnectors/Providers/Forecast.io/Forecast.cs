using Maba.Connectors.WeatherServices;
using Maba.Connectors.WeatherServices.Providers;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.WeatherServices.Extentions;
using Maba.Connectors.WeatherServices.Providers.Models;
using Maba.Connectors.WeatherServices.Providers.Models.Forecast;
using Maba.Connectors.WeatherServices.Forecast;
using Maba.Connectors.WeatherServices.Providers.Models.Types;

namespace Maba.Connectors.WeatherServices.Providers
{
    public class Forecast : IWeatherProvider
    {
        #region EXAMPLES

        //https://api.forecast.io/forecast/52bfe99737cd7f334b45b74cc6137393/37.8267,-122.423
        //https://api.forecast.io/forecast/52bfe99737cd7f334b45b74cc6137393/32.5333,35.53333?units=si

        #endregion

        #region CONSTANTS

        public const string PROVIDER_NAME = "Forecast";
        public static string BASE_URL = @"https://api.forecast.io/forecast/52bfe99737cd7f334b45b74cc6137393/{0},{1}?units={2}";

        #endregion

        #region properties

        public Settings.ProviderSetting ProviderSettings { get; private set; }

        #endregion

        #region ctor

        public Forecast(Settings.ProviderSetting provider)
        {
            ProviderSettings = provider;
        }

        #endregion

        #region IWeatherProvider members


        public string ProviderName
        {
            get
            {
                return PROVIDER_NAME;
            }
        }

        public string[] GetSupportedUnits()
        {
            return new string[]
            {
                //English units
                "us",
                //metric
                "si"
            };
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="lat"></param>
        /// <param name="lon"></param>
        /// <param name="MaxDays"></param>
        /// <param name="units">us=imperial,  si = metric</param>
        /// <returns></returns>
        public ForecastData GetForecast(decimal lat, decimal lon, int MaxDays, string units = "us")
        {
            try
            {
                // units == "imperial" ? "us" : "si"
                var api_url = $"https://api.forecast.io/forecast/{ProviderSettings.Key}/{lat},{lon}?units=si";

                WebRequest webRequest = HttpWebRequest.Create(api_url);
                webRequest.Method = "GET";
                var forecast = new ForecastData()
                {
                    location = new Location() { lat = lat, lon = lon },
                    forecastDays = MaxDays
                };

                using (var resp = webRequest.GetResponse())
                {
                    using (var sr = new System.IO.StreamReader(resp.GetResponseStream()))
                    {
                        JToken token = JObject.Parse(sr.ReadToEnd().Trim());
                        List<JToken> list = token["daily"]["data"].ToList();

                        forecast.forecastDays = Math.Min(forecast.forecastDays, list.Count);
                        forecast.providerData = new ProviderData(PROVIDER_NAME, token);

                        #region parsing days

                        forecast.forecastList = new SingleDayData[forecast.forecastDays];
                        for (int i = 0; i < forecast.forecastDays; i++)
                        {
                            var item = list[i];
                            SingleDayData ditem = new SingleDayData();
                            ditem.date = GetTimeHelper.ToDateTime((long)item["time"]);


                            #region Humidity

                            ditem.Humidity = new UnitObject() { ValueType = ValueTypes.AvgOnly };
                            ditem.Humidity.Avg = item["humidity"].Convert();

                            #endregion

                            #region precipitation


                            var _PrecipitationAllDay = item["precipProbability"].Convert();
                            decimal? _PrecipitationNight = null;
                            decimal? _PrecipitationDay = null;

                            var valueType = Wunderground_v2.FixValuesRange(ref _PrecipitationAllDay, ref _PrecipitationNight, ref _PrecipitationDay);
                            ditem.Prec_Inch = new PrecipitationObject() { ValueType = valueType };
                            ditem.Prec_mm = new PrecipitationObject() { ValueType = valueType };

                            if (units == "us")
                            {
                                ditem.Prec_Inch.Night = _PrecipitationNight;
                                ditem.Prec_Inch.Day = _PrecipitationDay;
                                ditem.Prec_Inch.Avg = _PrecipitationAllDay;

                                //get mm from Inch
                                ditem.Prec_mm.Night = Wunderground_v2.GetmmValue(_PrecipitationNight);
                                ditem.Prec_mm.Day = Wunderground_v2.GetmmValue(_PrecipitationDay);
                                ditem.Prec_mm.Avg = Wunderground_v2.GetmmValue(_PrecipitationAllDay);
                            }
                            else
                            {
                                ditem.Prec_mm.Night = _PrecipitationNight;
                                ditem.Prec_mm.Day = _PrecipitationDay;
                                ditem.Prec_mm.Avg = _PrecipitationAllDay;

                                //get mm from Inch
                                ditem.Prec_Inch.Night = Wunderground_v2.GetInchValue(_PrecipitationNight);
                                ditem.Prec_Inch.Day = Wunderground_v2.GetInchValue(_PrecipitationDay);
                                ditem.Prec_Inch.Avg = Wunderground_v2.GetInchValue(_PrecipitationAllDay);
                            }

                            #endregion

                            #region Temp

                            var _MinTemp = item["temperatureMin"].Convert();
                            var _MaxTemp = item["temperatureMax"].Convert();
                            decimal? _avgTemp = null;

                            var valuType = Wunderground_v2.FixValuesRange(ref _avgTemp, ref _MinTemp, ref _MaxTemp);
                            ditem.Temp_Fahrenheit = new UnitObject() { ValueType = valuType };
                            ditem.Temp_Celsius = new UnitObject() { ValueType = valuType };

                            if (units == "us")
                            {

                                ditem.Temp_Fahrenheit.Min = _MinTemp;
                                ditem.Temp_Fahrenheit.Max = _MaxTemp;
                                ditem.Temp_Fahrenheit.Avg = _avgTemp;

                                //convert C from F
                                ditem.Temp_Celsius.Min = Wunderground_v2.GetCelsiusValue(_MinTemp);
                                ditem.Temp_Celsius.Max = Wunderground_v2.GetCelsiusValue(_MaxTemp);
                                ditem.Temp_Celsius.Avg = Wunderground_v2.GetCelsiusValue(_avgTemp);
                            }
                            else
                            {
                                
                                ditem.Temp_Celsius.Min = _MinTemp;
                                ditem.Temp_Celsius.Max = _MaxTemp;
                                ditem.Temp_Celsius.Avg = _avgTemp;

                                //convert F from C
                                ditem.Temp_Fahrenheit.Min = Wunderground_v2.GetFahrenheitValue(_MinTemp);
                                ditem.Temp_Fahrenheit.Max = Wunderground_v2.GetFahrenheitValue(_MaxTemp);
                                ditem.Temp_Fahrenheit.Avg = Wunderground_v2.GetFahrenheitValue(_avgTemp);
                            }

                            #endregion

                            ditem.description = (string)item["summary"];
                            ditem.icon = GetIcon((string)item["icon"], "");

                            forecast.forecastList[i] = ditem;
                        }

                        #endregion
                    }
                }
                return forecast;
            }
            catch (Exception)
            {

                throw;
            }


        }

        #endregion

        #region private methods

        private string BuilIconPath(string key, string baseURL = null)
        {
            return string.Format(baseURL ?? ProviderSettings.Icons_URL, key);
        }

        private IconData GetIcon(string icon, string icon_url)
        {

            switch (icon)
            {
                case "clear-day":
                case "clear-night":
                    return new IconData()
                    {
                        Code = "sunny",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0001_sunny.png"),
                        Night_Url = BuilIconPath("wsymbol_0008_clear_sky_night.png")
                    };
                case "rain":
                    return new IconData()
                    {
                        Code = "cloudy_with_light_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0017_cloudy_with_light_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0033_cloudy_with_light_rain_night.png")
                    }; ;
                case "snow":
                    return new IconData()
                    {
                        Code = "cloudy_with_light_snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0019_cloudy_with_light_snow.png"),
                        Night_Url = BuilIconPath("wsymbol_0035_cloudy_with_light_snow_night.png")
                    };
                case "sleet":
                    return new IconData()
                    {
                        Code = "cloudy_with_sleet",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0021_cloudy_with_sleet.png"),
                        Night_Url = BuilIconPath("wsymbol_0037_cloudy_with_sleet_night.png")
                    };
                case "wind":
                    return new IconData()
                    {
                        Code = "windy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0060_windy.png"),
                        Night_Url = BuilIconPath("wsymbol_0078_windy_night.png")
                    };
                case "fog":
                    return new IconData()
                    {
                        Code = "fog",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0007_fog.png"),
                        Night_Url = BuilIconPath("wsymbol_0064_fog_night.png")
                    };
                case "cloudy":
                    return new IconData()
                    {
                        Code = "cloudy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0004_black_low_cloud.png"),
                        Night_Url = BuilIconPath("wsymbol_0042_cloudy_night.png")
                    }; ;
                case "partly-cloudy-day":
                case "partly-cloudy-night":
                    return new IconData()
                    {
                        Code = "sunny_intervals",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0002_sunny_intervals.png"),
                        Night_Url = BuilIconPath("wsymbol_0041_partly_cloudy_night.png")
                    };
                case "hail":
                    return new IconData()
                    {
                        Code = "hail",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0014_light_hail_showers.png"),
                        Night_Url = BuilIconPath("wsymbol_0038_cloudy_with_light_hail_night.png")
                    };
                case "thunderstorm":
                    return new IconData()
                    {
                        Code = "thunderstorms",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0024_thunderstorms.png"),
                        Night_Url = BuilIconPath("wsymbol_0040_thunderstorms_night.png")
                    }; ;
                case "tornado":
                    return new IconData()
                    {
                        Code = "tornado",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0079_tornado.png"),
                        Night_Url = BuilIconPath("wsymbol_0079_tornado.png")
                    }; ;
                default:
                    return new IconData()
                    {
                        Code = "unknown",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0999_unknown.png"),
                        Night_Url = BuilIconPath("wsymbol_0999_unknown.png")
                    }; ;
            }

        }

        #endregion
    }
}
