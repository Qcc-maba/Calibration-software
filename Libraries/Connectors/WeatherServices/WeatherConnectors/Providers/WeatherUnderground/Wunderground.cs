using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.WeatherServices.Extentions;
using Maba.Connectors.WeatherServices.Providers.Models;
using Maba.Connectors.WeatherServices.Providers.Models.Types;
using Maba.Connectors.WeatherServices.Forecast;
using Maba.Connectors.WeatherServices.Providers.Models.Forecast;

namespace Maba.Connectors.WeatherServices.Providers
{
    public class Wunderground : IWeatherProvider
    {
        #region CONSTANTS

        public const string PROVIDER_NAME = "Wunderground";

        #endregion

        #region properties

        public Settings.ProviderSetting ProviderSettings { get; private set; }

        #endregion

        #region private methods

        private ValueTypes FixValuesRange0(ref decimal? Avg, ref decimal? min, ref decimal? max)
        {
            if (min.HasValue && max.HasValue)
            {
                if (Avg.HasValue && ((min + max) / 2) != Avg)
                {
                    min = null;
                    max = null;
                    return ValueTypes.AvgOnly;
                }
                else if (min.HasValue && max.HasValue && min.Value == max.Value)
                {
                    min = null;
                    max = null;
                    return ValueTypes.AvgOnly;
                }

                Avg = (min + max) / 2;
                return ValueTypes.All;
            }
            else if (min.HasValue && !max.HasValue)
            {
                if (Avg.HasValue)
                {
                    max = (Avg * 2) - min.Value;
                    return ValueTypes.All;
                }
                else
                {
                    return ValueTypes.MinOnly;
                }
            }
            else if (!min.HasValue && max.HasValue)
            {
                if (Avg.HasValue)
                {
                    min = (Avg * 2) - max.Value;
                    return ValueTypes.All;
                }
                else
                {
                    return ValueTypes.MaxOnly;
                }
            }
            else //(!min.HasValue && !max.HasValue)
            {
                if (Avg.HasValue)
                {
                    return ValueTypes.AvgOnly;
                }
                else
                {
                    return ValueTypes.None;
                }
            }
        }

        #endregion

        #region ctor

        public Wunderground(Settings.ProviderSetting provider)
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
                "imperial",
                "metric"
            };
        }

        public ForecastData GetForecast(decimal lat, decimal lon, int MaxDays, string units = "imperial")
        {
            try
            {
                //old way
                var api_url = $"http://api.wunderground.com/api/{ProviderSettings.Key}/forecast10day/q/{lat},{lon}.json";

                //in new way:
                //var BaseUrl = string.Format(setting.BaseUrl,lat, lon,setting.Key);
                WebRequest webRequest = HttpWebRequest.Create(api_url);
                webRequest.Method = "GET";
                var forecast = new ForecastData()
                {
                    forecastDays = MaxDays
                };

                using (var resp = webRequest.GetResponse())
                {
                    using (var sr = new System.IO.StreamReader(resp.GetResponseStream()))
                    {
                        JToken token = JObject.Parse(sr.ReadToEnd().Trim());


                        forecast.location = new Location() { lat = lat, lon = lon };
                        List<JToken> list = token["forecast"]["simpleforecast"]["forecastday"].ToList();

                        forecast.forecastDays = Math.Min(forecast.forecastDays, list.Count);
                        forecast.providerData = new ProviderData(PROVIDER_NAME, token);

                        #region days

                        forecast.forecastList = new SingleDayData[forecast.forecastDays];
                        for (int i = 0; i < forecast.forecastDays; i++)
                        {
                            var item = list[i];
                            SingleDayData ditem = new SingleDayData();
                            ditem.date = GetTimeHelper.ToDateTime((long)item["date"]["epoch"]);

                            #region Humidity

                            var _MinHumidity = item["minhumidity"].Convert();
                            var _MaxHumidity = item["maxhumidity"].Convert();
                            var _AvgHumidity = item["avehumidity"].Convert();

                            ditem.Humidity = new UnitObject() { ValueType = Wunderground_v2.FixValuesRange(ref _AvgHumidity, ref _MinHumidity, ref _MaxHumidity) };
                       
                           
                            ditem.Humidity.Min = _MinHumidity;
                            ditem.Humidity.Max = _MaxHumidity;
                            ditem.Humidity.Avg = _AvgHumidity;

                            #endregion

                            #region Temp

                            var _MinTemp = (units == "imperial" ? item["high"]["fahrenheit"] : item["high"]["celsius"]).Convert();
                            var _MaxTemp = (units == "imperial" ? item["low"]["fahrenheit"] : item["low"]["celsius"]).Convert();
                            decimal? _avgTemp = null;

                            var TempValueType = Wunderground_v2.FixValuesRange(ref _avgTemp, ref _MinTemp, ref _MaxTemp);
                            ditem.Temp_Fahrenheit = new UnitObject() { ValueType = TempValueType };
                            ditem.Temp_Celsius = new UnitObject() { ValueType = TempValueType };

                            if (units == "imperial")
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

                            #region Precipitation

                            var _PrecipitationDay = (units == "imperial" ? item["qpf_day"]["in"] : item["qpf_day"]["mm"]).Convert();
                            var _PrecipitationNight = (units == "imperial" ? item["qpf_day"]["in"] : item["qpf_day"]["mm"]).Convert();
                            var _PrecipitationAllDay = (units == "imperial" ? item["qpf_allday"]["in"] : item["qpf_allday"]["mm"]).Convert();

                           var p_Type = Wunderground_v2.FixValuesRange(ref _PrecipitationAllDay, ref _PrecipitationNight, ref _PrecipitationDay);

                            ditem.Prec_Inch = new PrecipitationObject() { ValueType = p_Type };
                            ditem.Prec_mm = new PrecipitationObject() { ValueType = p_Type };



                            if (units == "imperial")
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

                            ditem.icon = GetIcon((string)item["icon"], (string)item["icon_url"]);
                            ditem.description = (string)item["conditions"];

                            forecast.forecastList[i] = ditem;
                        }

                        #endregion
                    }
                }

                forecast.IsValid = true;
                return forecast;
            }
            catch (Exception e)
            {
                return new ForecastData()
                {
                    IsValid = false
                };
            }
        }

        #endregion

        #region private methods

        private string BuilIconPath(string key, string baseURL = null)
        {
            return string.Format(baseURL ?? this.ProviderSettings.Icons_URL, key);
        }

        private IconData GetIcon(string icon, string icon_url)
        {
            switch (icon)
            {
                case "chanceflurries":
                    return new IconData()
                    {
                        Code = "light_snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0011_light_snow_showers.png"),
                        Night_Url = BuilIconPath("wsymbol_0027_light_snow_showers_night.png")
                    }
                      ;
                case "chancerain":
                    return new IconData()
                    {
                        Code = "cloudy_with_light_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0017_cloudy_with_light_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0033_cloudy_with_light_rain_night.png")
                    };

                case "chancesleet":
                    return new IconData()
                    {
                        Code = "freezing_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0050_freezing_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0068_freezing_rain_night.png")
                    };
                case "chancesnow":
                    return new IconData()
                    {
                        Code = "cloudy_with_light_snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0019_cloudy_with_light_snow.png"),
                        Night_Url = BuilIconPath("wsymbol_0035_cloudy_with_light_snow_night.png")
                    };
                case "chancetstorms":
                    return new IconData()
                    {
                        Code = "thunderstorms",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0024_thunderstorms.png"),
                        Night_Url = BuilIconPath("wsymbol_0040_thunderstorms_night.png")
                    };
                case "clear":
                    return new IconData()
                    {
                        Code = "sunny",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0001_sunny.png"),
                        Night_Url = BuilIconPath("wsymbol_0008_clear_sky_night.png")
                    };
                case "cloudy":
                    return new IconData()
                    {
                        Code = "cloudy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0004_black_low_cloud.png"),
                        Night_Url = BuilIconPath("wsymbol_0042_cloudy_night.png")
                    };
                case "flurries":
                    return new IconData()
                    {
                        Code = "heavy_snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0012_heavy_snow_showers.png"),
                        Night_Url = BuilIconPath("wsymbol_0028_heavy_snow_showers_night.png")
                    };
                case "fog":
                    return new IconData()
                    {
                        Code = "fog",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0007_fog.png"),
                        Night_Url = BuilIconPath("wsymbol_0064_fog_night.png")
                    };
                case "hazy":
                    return new IconData()
                    {
                        Code = "hazy_sun",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0005_hazy_sun.png"),
                        Night_Url = BuilIconPath("wsymbol_0041_partly_cloudy_night.png")
                    };
                case "mostlycloudy":
                    return new IconData()
                    {
                        Code = "mostly_cloudy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0043_mostly_cloudy.png"),
                        Night_Url = BuilIconPath("wsymbol_0044_mostly_cloudy_night.png")
                    };
                case "mostlysunny":
                case "partlycloudy":
                    return new IconData()
                    {
                        Code = "sunny_intervals",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0002_sunny_intervals.png"),
                        Night_Url = BuilIconPath("wsymbol_0041_partly_cloudy_night.png")
                    };
                case "partlysunny":
                    return new IconData()
                    {
                        Code = "mostly_cloudy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0043_mostly_cloudy.png"),
                        Night_Url = BuilIconPath("wsymbol_0044_mostly_cloudy_night.png")
                    };
                case "sleet":
                    return new IconData()
                    {
                        Code = "freezing_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0050_freezing_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0068_freezing_rain_night.png")
                    };
                case "rain":
                    return new IconData()
                    {
                        Code = "cloudy_with_heavy_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0018_cloudy_with_heavy_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0034_cloudy_with_heavy_rain_night.png")
                    };
                case "snow":
                    return new IconData()
                    {
                        Code = "cloudy_with_heavy_snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0020_cloudy_with_heavy_snow.png"),
                        Night_Url = BuilIconPath("wsymbol_0036_cloudy_with_heavy_snow_night.png")
                    };
                case "sunny":
                    return new IconData()
                    {
                        Code = "sunny",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0001_sunny.png"),
                        Night_Url = BuilIconPath("wsymbol_0008_clear_sky_night.png")
                    };
                case "tstorms":
                    return new IconData()
                    {
                        Code = "thunderstorms",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0024_thunderstorms.png"),
                        Night_Url = BuilIconPath("wsymbol_0040_thunderstorms_night.png")
                    };
                default:
                    return new IconData()
                    {
                        Code = "unknown",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0999_unknown.png"),
                        Night_Url = BuilIconPath("wsymbol_0999_unknown.png")
                    };
            }
        }

        #endregion
    }
}
