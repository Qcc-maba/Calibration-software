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
using Maba.Connectors.WeatherServices.History;
using Maba.Connectors.WeatherServices.Providers.Models.History;
using Maba.Connectors.WeatherServices.Forecast;
using Maba.Connectors.WeatherServices.Providers.Models.Forecast;
using Maba.Connectors.WeatherServices.Providers.Models.Current;

namespace Maba.Connectors.WeatherServices.Providers
{
    public class Wunderground_v2 : IWeatherProvider, IWeatherProviderHistorical, IWeatherProviderCurrentObservations
    {
        #region CONSTANTS

        public const string PROVIDER_NAME = "Wunderground_v2";

        #endregion

        #region properties

        public Settings.ProviderSetting ProviderSettings { get; private set; }

        #endregion

        #region ctor

        public Wunderground_v2(Settings.ProviderSetting provider)
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
                "e",
                //metric
                "m",
                //Hybrid Units(UK) - supported in Provider but in this connector
                //"h"
            };
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="lat"></param>
        /// <param name="lon"></param>
        /// <param name="MaxDays"></param>
        /// <param name="units">e=English Units, m-Metric Units, h=Hybrid Units(UK)</param>
        /// <returns></returns>
        public ForecastData GetForecast(decimal lat, decimal lon, int MaxDays, string units)
        {
            units = units ?? "e";
            try
            {
                var api_URL = $"http://api.weather.com/v1/geocode/{lat}/{lon}/forecast/daily/7day.json?apiKey={ProviderSettings.Key}&units={units}";

                WebRequest webRequest = HttpWebRequest.Create(api_URL);
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
                        forecast.providerData = new ProviderData(PROVIDER_NAME, token);

                        List<JToken> list = token["forecasts"].ToList();
                        forecast.forecastDays = Math.Min(forecast.forecastDays, list.Count);
                        forecast.forecastList = new SingleDayData[forecast.forecastDays];
                        forecast.Data = token.ToString();
                        #region parsing days

                        for (int i = 0; i < forecast.forecastDays; i++)
                        {
                            var item = list[i];
                            SingleDayData ditem = new SingleDayData();
                            ditem.date = GetTimeHelper.ToDateTime((long)item["fcst_valid"]);
                            ditem.DayNum = (int)item["num"].Convert();

                            #region Humidity

                            decimal? _MinHumidity = item["night"] != null ? item["night"]["rh"].Convert() : null;
                            decimal? _MaxHumidity = item["day"] != null ? item["day"]["rh"].Convert() : null;
                            decimal? _AvgHumidity = null;
                            ditem.Humidity = new UnitObject() { ValueType = FixValuesRange(ref _AvgHumidity, ref _MinHumidity, ref _MaxHumidity) };

                            ditem.Humidity.Min = _MinHumidity;
                            ditem.Humidity.Max = _MaxHumidity;
                            ditem.Humidity.Avg = _AvgHumidity;

                            #endregion

                            #region Temp

                            var _MinTemp = item["min_temp"].Convert();
                            var _MaxTemp = item["max_temp"].Convert();
                            decimal? _avgTemp = null;

                            var valu_type = FixValuesRange(ref _avgTemp, ref _MinTemp, ref _MaxTemp);
                            ditem.Temp_Fahrenheit = new UnitObject() { ValueType = valu_type };
                            ditem.Temp_Celsius = new UnitObject() { ValueType = valu_type };

                            if (units == "e")
                            {
                                ditem.Temp_Fahrenheit.Min = _MinTemp;
                                ditem.Temp_Fahrenheit.Max = _MaxTemp;
                                ditem.Temp_Fahrenheit.Avg = _avgTemp;

                                //convert C from F
                                ditem.Temp_Celsius.Min = GetCelsiusValue(_MinTemp);
                                ditem.Temp_Celsius.Max = GetCelsiusValue(_MaxTemp);
                                ditem.Temp_Celsius.Avg = GetCelsiusValue(_avgTemp);
                            }
                            else
                            {
                                ditem.Temp_Celsius.Min = _MinTemp;
                                ditem.Temp_Celsius.Max = _MaxTemp;
                                ditem.Temp_Celsius.Avg = _avgTemp;

                                //convert F from C
                                ditem.Temp_Fahrenheit.Min = GetFahrenheitValue(_MinTemp);
                                ditem.Temp_Fahrenheit.Max = GetFahrenheitValue(_MaxTemp);
                                ditem.Temp_Fahrenheit.Avg = GetFahrenheitValue(_avgTemp);
                            }

                            #endregion

                            #region Precipitation

                            var _PrecipitationDay = item["day"] != null ? item["day"]["qpf"].Convert() : null;
                            var _PrecipitationNight = item["night"] != null ? item["night"]["qpf"].Convert() : null;
                            decimal? _PrecipitationAllDay = _PrecipitationNight;
                            var p_value = FixValuesRange(ref _PrecipitationAllDay, ref _PrecipitationNight, ref _PrecipitationDay);


                            ditem.Prec_mm = new PrecipitationObject() { ValueType = p_value };
                            ditem.Prec_Inch = new PrecipitationObject() { ValueType = p_value };

                            if (units == "e")
                            {
                                ditem.Prec_Inch.Night = _PrecipitationNight;
                                ditem.Prec_Inch.Day = _PrecipitationDay;
                                ditem.Prec_Inch.Avg = _PrecipitationAllDay;

                                //get mm from Inch
                                ditem.Prec_mm.Night = GetmmValue(_PrecipitationNight);
                                ditem.Prec_mm.Day = GetmmValue(_PrecipitationDay);
                                ditem.Prec_mm.Avg = GetmmValue(_PrecipitationAllDay);
                            }
                            else
                            {
                                ditem.Prec_mm.Night = _PrecipitationNight;
                                ditem.Prec_mm.Day = _PrecipitationDay;
                                ditem.Prec_mm.Avg = _PrecipitationAllDay;

                                //get mm from Inch
                                ditem.Prec_Inch.Night = GetInchValue(_PrecipitationNight);
                                ditem.Prec_Inch.Day = GetInchValue(_PrecipitationDay);
                                ditem.Prec_Inch.Avg = GetInchValue(_PrecipitationAllDay);
                            }

                            var PecipitationPercentDay = item["day"] != null ? item["day"]["pop"].Convert() : null;
                            var PecipitationPercentNight = item["night"] != null ? item["night"]["pop"].Convert() : null;
                            decimal? _PecipitationPercentAllDay = PecipitationPercentDay;
                            var Percent_value = FixValuesRange(ref _PecipitationPercentAllDay, ref PecipitationPercentNight, ref PecipitationPercentDay);
                            ditem.Prec_Percent = new PrecipitationObject()
                            {
                                ValueType = Percent_value,
                                Avg = _PecipitationPercentAllDay,
                                Day = PecipitationPercentDay,
                                Night = PecipitationPercentNight
                            };

                            #endregion

                            if (item["day"] != null)
                            {
                                ditem.icon = GetIcon((int)item["day"]["icon_code"]);
                            }
                            else if (item["night"] != null)
                            {
                                ditem.icon = GetIcon((int)item["night"]["icon_code"]);
                            }
                            ditem.description = (string)item["shortcast"];

                            forecast.forecastList[i] = ditem;
                        }

                        #endregion
                    }
                }

                forecast.IsValid = true;
                return forecast;
            }
            catch (Exception)
            {
                return new ForecastData()
                {
                    IsValid = false
                };
            }
        }


        #endregion

        #region IWeatherProviderHistorical members

        public ObservationsData GetHistorical(decimal lat, decimal lon, DateTime startDate, DateTime? endDate, string units)
        {
            try
            {
                string api_URL = null;
                var str_startDate = startDate.ToString("yyyyMMdd");
                if (endDate.HasValue)
                {
                    var str_endDate = endDate.Value.ToString("yyyyMMdd");
                    api_URL = $"https://api.weather.com/v1/geocode/{lat}/{lon}/observations/historical.json?units={units}&startDate={str_startDate}&endDate={str_endDate}&apiKey={ProviderSettings.Key}";
                }
                else
                {
                    api_URL = $"https://api.weather.com/v1/geocode/{lat}/{lon}/observations/historical.json?units={units}&startDate={str_startDate}&apiKey={ProviderSettings.Key}";
                }

                WebRequest webRequest = HttpWebRequest.Create(api_URL);
                webRequest.Method = "GET";
                var historical = new ObservationsData();


                using (var resp = webRequest.GetResponse())
                {
                    using (var sr = new System.IO.StreamReader(resp.GetResponseStream()))
                    {
                        JToken token = JObject.Parse(sr.ReadToEnd().Trim());
                        historical.providerData = new ProviderData(PROVIDER_NAME, token);

                        List<JToken> list = token["observations"].ToList();
                        //historical.historyDays = Math.Min(historical.historyDays, list.Count);
                        historical.historyDays = list.Count;
                        historical.historyData = new HistoryDayData[historical.historyDays];
                        historical.Data = token.ToString();
                        #region parsing days

                        for (int i = 0; i < historical.historyDays; i++)
                        {
                            var item = list[i];
                            HistoryDayData ditem = new HistoryDayData();
                            ditem.date = GetTimeHelper.ToDateTime((long)item["expire_time_gmt"]);
                            ditem.dt = (long)item["expire_time_gmt"];

                            #region Temp

                            var _MinTemp = item["min_temp"].Convert();
                            var _MaxTemp = item["max_temp"].Convert();
                            decimal? _avgTemp = item["temp"].Convert();
                            var TempValueType = FixValuesRange(ref _avgTemp, ref _MinTemp, ref _MaxTemp);

                            ditem.Temp_Fahrenheit = new UnitObject() { ValueType = TempValueType };
                            ditem.Temp_Celsius = new UnitObject() { ValueType = TempValueType };

                            if (units == "e")
                            {

                                ditem.Temp_Fahrenheit.Min = _MinTemp;
                                ditem.Temp_Fahrenheit.Max = _MaxTemp;
                                ditem.Temp_Fahrenheit.Avg = _avgTemp;

                                //convert C from F
                                ditem.Temp_Celsius.Min = GetCelsiusValue(_MinTemp);
                                ditem.Temp_Celsius.Max = GetCelsiusValue(_MaxTemp);
                                ditem.Temp_Celsius.Avg = GetCelsiusValue(_avgTemp);
                            }
                            else
                            {
                                ditem.Temp_Celsius.Min = _MinTemp;
                                ditem.Temp_Celsius.Max = _MaxTemp;
                                ditem.Temp_Celsius.Avg = _avgTemp;

                                //convert F from C
                                ditem.Temp_Fahrenheit.Min = GetFahrenheitValue(_MinTemp);
                                ditem.Temp_Fahrenheit.Max = GetFahrenheitValue(_MaxTemp);
                                ditem.Temp_Fahrenheit.Avg = GetFahrenheitValue(_avgTemp);
                            }

                            #endregion

                            #region Precipitation
                            var pre = item["precip_total"].Convert(0);
                            var pre_hrly = item["precip_hrly"].Convert(0);
                            var snow_hrly = item["snow_hrly"].Convert(0);

                            if (units == "e")
                            {
                                ditem.Prec_Inch = new SumUnitObject() { Hourly = pre_hrly, Total = pre };
                                ditem.Snow_Inch = new SumUnitObject() { Hourly = snow_hrly };
                                ditem.Prec_mm = new SumUnitObject() { Hourly = GetmmValue(pre_hrly), Total = GetmmValue(pre) };
                                ditem.Snow_mm = new SumUnitObject { Hourly = GetmmValue(snow_hrly) };
                            }
                            else
                            {
                                ditem.Prec_Inch = new SumUnitObject() { Hourly = GetInchValue(pre_hrly), Total = GetInchValue(pre) };
                                ditem.Snow_Inch = new SumUnitObject() { Hourly = GetInchValue(snow_hrly) };
                                ditem.Prec_mm = new SumUnitObject() { Hourly = pre_hrly, Total = pre };
                                ditem.Snow_mm = new SumUnitObject { Hourly = snow_hrly };
                            }
                            #endregion

                            ditem.Description_Phrase = item["terse_phrase"].ToString();
                            ditem.Description_Phrase2 = item["blunt_phrase"].ToString();
                            ditem.Description_Qualifier = item["qualifier"].ToString();
                            ditem.DescriptionWeather = item["wx_phrase"].ToString();
                            ditem.Description_Rank = item["qualifier_svrty"].Convertint();
                            ditem.Daytime = GetTypeDaytime(item["day_ind"].ToString());
                            ditem.StationID = item["obs_id"].ToString();
                            ditem.StationName = item["obs_name"].ToString();
                            ditem.DewPoint = item["dewPt"].Convertint();
                            ditem.icon = GetIcon(item["wx_icon"].Convertint().GetValueOrDefault(0));
                            ditem.Pressure = (Double?)item["pressure"].Convert();
                            ditem.Pressure_desc = item["pressure_desc"].ToString();
                            ditem.Pressure_tend = item["pressure_tend"].Convertint();
                            ditem.CloudCover = item["clds"].ToString();
                            ditem.Visibilities = (Double)item["vis"].Convert(0);
                            ditem.WindSpeed = item["wspd"].Convertint();
                            ditem.WindDirection = item["wdir"].Convertint();

                            #region Humidity

                            decimal? _MinHumidity = item["rh"].Convert();
                            ditem.AvgHumidity = _MinHumidity;

                            #endregion

                            historical.historyData[i] = ditem;
                        }

                        #endregion
                    }
                }

                historical.IsValid = true;
                return historical;
            }
            catch (Exception)
            {
                return new ObservationsData()
                {
                    IsValid = false
                };
            }
        }


        #endregion

        #region IWeatherProviderCurrentObservations
        public CurrentConditionsObservation GetCurrentObservations(decimal lat, decimal lon, string units)
        {
            try
            {
                string api_URL = $"https://api.weather.com/v1/geocode/{lat}/{lon}/observations/current.json?&units={units}&apiKey={ProviderSettings.Key}";

                WebRequest webRequest = HttpWebRequest.Create(api_URL);
                webRequest.Method = "GET";
                var Observations = new CurrentConditionsObservation();
                using (var resp = webRequest.GetResponse())
                {
                    using (var sr = new System.IO.StreamReader(resp.GetResponseStream()))
                    {
                        JToken token = JObject.Parse(sr.ReadToEnd().Trim());
                        Observations.providerData = new ProviderData(PROVIDER_NAME, token);
                        token = token["observation"];
                        var DataItem = new CurrentConditionsData();
                        Observations.ObservationsData = DataItem;
                        Observations.location = new Location()
                        {
                            lat = lat,
                            lon = lon
                        };

                        Observations.Data = token.ToString();
                        DataItem.Expire_Time = ((long)token["expire_time_gmt"]);
                        DataItem.Obs_Time = ((long)token["obs_time"]);
                        DataItem.Obs_Time_Local = ((DateTime)token["obs_time_local"]);
                        DataItem.DayOfWeek = token["dow"].ToString();
                        DataItem.WindDirection = token["wdir"].Convertint();
                        DataItem.WindDirection_Cardinal = token["wdir_cardinal"].Convertint();
                        DataItem.icon = GetIcon(token["icon_code"].Convertint().GetValueOrDefault(0));
                        DataItem.DescriptionWeather = token["phrase_32char"].ToString();
                        DataItem.DescriptionCloudCover = token["sky_cover"].ToString();
                        DataItem.CloudCover = token["clds"].ToString();
                        DataItem.Description_Phrase = token["ptend_desc"].ToString();
                        DataItem.Phrase_Code = token["ptend_code"].Convertint();
                        DataItem.SunriseDate = ((DateTime)token["sunrise"]);
                        DataItem.SunsetDate = ((DateTime)token["sunset"]);
                        DataItem.Daytime = GetTypeDaytime(token["day_ind"].ToString());


                        var token_internal = units == "e" ? token["imperial"] : token["metric"];
                        DataItem.Pressure = (Double)token_internal["pchange"].Convert(0);
                        DataItem.DewPoint = token_internal["dewpt"].Convertint();
                        DataItem.WindSpeed = token_internal["wspd"].Convertint();
                        DataItem.WindSpeedAverage = token_internal["gust"].Convertint();
                        DataItem.Visibilities = (Double)token_internal["vis"].Convert(0);
                        DataItem.AvgHumidity = token_internal["rh"].Convert(0);

                        #region Temp

                        var _MinTemp = token_internal["temp_min_24hour"].Convert();
                        var _MinTemp_ = _MinTemp;
                        var _MaxTemp = token_internal["temp_max_24hour"].Convert();
                        var _MaxTemp_ = _MaxTemp;
                        decimal? _avgTemp = token_internal["temp"].Convert();
                        var TempValueType = FixValuesRange(ref _avgTemp, ref _MinTemp_, ref _MaxTemp_);
                        DataItem.Temp_Fahrenheit = new UnitObject() { ValueType = TempValueType };
                        DataItem.Temp_Celsius = new UnitObject() { ValueType = TempValueType };

                        if (units == "e")
                        {

                            DataItem.Temp_Fahrenheit.Min = _MinTemp;
                            DataItem.Temp_Fahrenheit.Max = _MaxTemp;
                            DataItem.Temp_Fahrenheit.Avg = _avgTemp;

                            //convert C from F
                            DataItem.Temp_Celsius.Min = GetCelsiusValue(_MinTemp);
                            DataItem.Temp_Celsius.Max = GetCelsiusValue(_MaxTemp);
                            DataItem.Temp_Celsius.Avg = GetCelsiusValue(_avgTemp);
                        }
                        else
                        {
                            DataItem.Temp_Celsius.Min = _MinTemp;
                            DataItem.Temp_Celsius.Max = _MaxTemp;
                            DataItem.Temp_Celsius.Avg = _avgTemp;

                            //convert F from C
                            DataItem.Temp_Fahrenheit.Min = GetFahrenheitValue(_MinTemp);
                            DataItem.Temp_Fahrenheit.Max = GetFahrenheitValue(_MaxTemp);
                            DataItem.Temp_Fahrenheit.Avg = GetFahrenheitValue(_avgTemp);
                        }

                        #endregion



                        #region Prec

                        var pre_1hour = token_internal["precip_1hour"].Convert(0);
                        var pre_6hour = token_internal["precip_6hour"].Convert(0);
                        var pre_24hour = token_internal["precip_24hour"].Convert(0);
                        var precip_mtd = token_internal["precip_mtd"].Convert(0);
                        var precip_ytd = token_internal["precip_ytd"].Convert(0);
                        var precip_2day = token_internal["precip_2day"].Convert(0);
                        var precip_3day = token_internal["precip_3day"].Convert(0);
                        var precip_7ay = token_internal["precip_7day"].Convert(0);

                        if (units == "e")
                        {
                            DataItem.Prec_Inch = new SumPeriod()
                            {
                                Hour_1 = pre_1hour,
                                Hour_6 = pre_6hour,
                                Hour_24 = pre_24hour,
                                Monthly = precip_mtd,
                                Yearly = precip_ytd,
                                Day_2 = precip_2day,
                                Day_3 = precip_3day,
                                Day_7 = precip_7ay
                            };

                            DataItem.Prec_mm = new SumPeriod()
                            {
                                Hour_1 = GetmmValue(pre_1hour),
                                Hour_6 = GetmmValue(pre_6hour),
                                Hour_24 = GetmmValue(pre_24hour),
                                Monthly = GetmmValue(precip_mtd),
                                Yearly = GetmmValue(precip_ytd),
                                Day_2 = GetmmValue(precip_2day),
                                Day_3 = GetmmValue(precip_3day),
                                Day_7 = GetmmValue(precip_7ay)
                            };
                        }
                        else
                        {
                            DataItem.Prec_mm = new SumPeriod()
                            {
                                Hour_1 = pre_1hour,
                                Hour_6 = pre_6hour,
                                Hour_24 = pre_24hour,
                                Monthly = precip_mtd,
                                Yearly = precip_ytd,
                                Day_2 = precip_2day,
                                Day_3 = precip_3day,
                                Day_7 = precip_7ay
                            };

                            DataItem.Prec_Inch = new SumPeriod()
                            {
                                Hour_1 = GetInchValue(pre_1hour),
                                Hour_6 = GetInchValue(pre_6hour),
                                Hour_24 = GetInchValue(pre_24hour),
                                Monthly = GetInchValue(precip_mtd),
                                Yearly = GetInchValue(precip_ytd),
                                Day_2 = GetInchValue(precip_2day),
                                Day_3 = GetInchValue(precip_3day),
                                Day_7 = GetInchValue(precip_7ay)
                            };
                        }


                        #endregion

                        #region Snow

                        var snow_1hour = token_internal["snow_1hour"].Convert(0);
                        var snow_6hour = token_internal["snow_6hour"].Convert(0);
                        var snow_24hour = token_internal["snow_24hour"].Convert(0);
                        var snow_mtd = token_internal["snow_mtd"].Convert(0);
                        var snow_ytd = token_internal["snow_ytd"].Convert(0);
                        var snow_2day = token_internal["snow_2day"].Convert(0);
                        var snow_3day = token_internal["snow_3day"].Convert(0);
                        var snow_7ay = token_internal["snow_7day"].Convert(0);
                        var snow_season = token_internal["snow_season"].Convert(0);

                        if (units == "e")
                        {
                            DataItem.Snow_Inch = new SumPeriod()
                            {
                                Hour_1 = snow_1hour,
                                Hour_6 = snow_6hour,
                                Hour_24 = snow_24hour,
                                Monthly = snow_mtd,
                                Yearly = snow_ytd,
                                Day_2 = snow_2day,
                                Day_3 = snow_3day,
                                Day_7 = snow_7ay,
                                Season = snow_season
                            };

                            DataItem.Snow_mm = new SumPeriod()
                            {
                                Hour_1 = GetmmValue(snow_1hour),
                                Hour_6 = GetmmValue(snow_6hour),
                                Hour_24 = GetmmValue(snow_24hour),
                                Monthly = GetmmValue(snow_mtd),
                                Yearly = GetmmValue(snow_ytd),
                                Day_2 = GetmmValue(snow_2day),
                                Day_3 = GetmmValue(snow_3day),
                                Day_7 = GetmmValue(snow_7ay),
                                Season = GetmmValue(snow_season)
                            };
                        }
                        else
                        {
                            DataItem.Snow_mm = new SumPeriod()
                            {
                                Hour_1 = snow_1hour,
                                Hour_6 = snow_6hour,
                                Hour_24 = snow_24hour,
                                Monthly = snow_mtd,
                                Yearly = snow_ytd,
                                Day_2 = snow_2day,
                                Day_3 = snow_3day,
                                Day_7 = snow_7ay,
                                Season = snow_season
                            };

                            DataItem.Snow_Inch = new SumPeriod()
                            {
                                Hour_1 = GetInchValue(snow_1hour),
                                Hour_6 = GetInchValue(snow_6hour),
                                Hour_24 = GetInchValue(snow_24hour),
                                Monthly = GetInchValue(snow_mtd),
                                Yearly = GetInchValue(snow_ytd),
                                Day_2 = GetInchValue(snow_2day),
                                Day_3 = GetInchValue(snow_3day),
                                Day_7 = GetInchValue(snow_7ay),
                                Season = GetInchValue(snow_season)
                            };
                        }


                        #endregion

                    }
                }

                Observations.IsValid = true;
                return Observations;
            }
            catch
            {
                return new CurrentConditionsObservation()
                {
                    IsValid = false
                };
            }


        }

        #endregion

        #region private methods


        public DaytimeTypes GetTypeDaytime(string str)
        {
            switch (str)
            {
                case "D": return DaytimeTypes.Day;
                case "N": return DaytimeTypes.Day;
                default:
                    return DaytimeTypes.None;
            }
        }

        private string BuilIconPath(string key, string baseURL = null)
        {
            return string.Format(baseURL ?? this.ProviderSettings.Icons_URL, key);
        }

        public IconData GetIcon(int icon, string icon_url = null)
        {
            switch (icon)
            {
                case 3:
                case 4:
                    return new IconData()
                    {
                        Code = "thunderstorms",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0024_thunderstorms.png"),
                        Night_Url = BuilIconPath("wsymbol_0040_thunderstorms_night.png")
                    };
                case 5:
                case 6:
                case 7:
                case 8:
                case 10:
                case 17:
                case 35:
                    return new IconData()
                    {
                        Code = "cloudy_with_sleet",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0021_cloudy_with_sleet.png"),
                        Night_Url = BuilIconPath("wsymbol_0037_cloudy_with_sleet_night.png")
                    };
                case 9:
                case 26:
                    return new IconData()
                    {
                        Code = "Drizzl",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0048_drizzle.png"),
                        Night_Url = BuilIconPath("wsymbol_0066_drizzle_night.png")
                    };
                case 11:
                    return new IconData()
                    {
                        Code = "Shower",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0017_cloudy_with_light_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0017_cloudy_with_light_rain.png")
                    }
                      ;
                case 12:
                    return new IconData()
                    {
                        Code = "cloudy_with_light_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0017_cloudy_with_light_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0033_cloudy_with_light_rain_night.png")
                    };
                case 13:
                case 14:
                case 15:
                case 16:
                case 42:
                case 43:
                case 46:
                    return new IconData()
                    {
                        Code = "snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0019_cloudy_with_light_snow.png"),
                        Night_Url = BuilIconPath("wsymbol_0019_cloudy_with_light_snow.png")
                    };
                case 18:
                    return new IconData()
                    {
                        Code = "freezing_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0050_freezing_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0068_freezing_rain_night.png")
                    };
                case 19:
                case 20:
                case 21:
                case 22:
                    return new IconData()
                    {
                        Code = "fog",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0007_fog.png"),
                        Night_Url = BuilIconPath("wsymbol_0064_fog_night.png")
                    };
                case 23:
                case 24:
                    return new IconData()
                    {
                        Code = "windy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0060_windy.png"),
                        Night_Url = BuilIconPath("wsymbol_0078_windy_night.png")
                    };
                case 25:
                    return new IconData()
                    {
                        Code = "Frigid",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0014_light_hail_showers.png"),
                        Night_Url = BuilIconPath("wsymbol_0038_cloudy_with_light_hail_night.png")
                    };
                case 27:
                case 28:
                case 30:
                    return new IconData()
                    {
                        Code = "cloudy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0004_black_low_cloud.png"),
                        Night_Url = BuilIconPath("wsymbol_0042_cloudy_night.png")
                    };
                case 29:
                    return new IconData()
                    {
                        Code = "sunny_intervals",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0002_sunny_intervals.png"),
                        Night_Url = BuilIconPath("wsymbol_0041_partly_cloudy_night.png")
                    };
                case 31:
                case 32:
                case 36:
                    return new IconData()
                    {
                        Code = "sunny",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0001_sunny.png"),
                        Night_Url = BuilIconPath("wsymbol_0008_clear_sky_night.png")
                    };

                case 33:
                case 34:
                    return new IconData()
                    {
                        Code = "mostly_cloudy",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0043_mostly_cloudy.png"),
                        Night_Url = BuilIconPath("wsymbol_0044_mostly_cloudy_night.png")
                    };
                case 37:
                case 38:
                case 47:
                    return new IconData()
                    {
                        Code = "thunderstorms",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0024_thunderstorms.png"),
                        Night_Url = BuilIconPath("wsymbol_0040_thunderstorms_night.png")
                    };
                case 39:
                case 40:
                    return new IconData()
                    {
                        Code = "cloudy_with_heavy_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0018_cloudy_with_heavy_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0034_cloudy_with_heavy_rain_night.png")
                    };


              
                case 41:
                    return new IconData()
                    {
                        Code = "heavy_snow",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0012_heavy_snow_showers.png"),
                        Night_Url = BuilIconPath("wsymbol_0028_heavy_snow_showers_night.png")
                    };
                case 45:
                    return new IconData()
                    {
                        Code = "cloudy_with_heavy_rain",
                        Provider_Url = icon_url,
                        Day_Url = BuilIconPath("wsymbol_0018_cloudy_with_heavy_rain.png"),
                        Night_Url = BuilIconPath("wsymbol_0034_cloudy_with_heavy_rain_night.png")
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

        #region internal methods

        internal static decimal? GetmmValue(decimal? inc_value)
        {
            if (inc_value.HasValue)
                return decimal.Round((inc_value.Value / 0.039370m), 2);
            else
                return null;
        }
        internal static decimal? GetInchValue(decimal? mm_value)
        {
            if (mm_value.HasValue)
                return decimal.Round((mm_value.Value * 0.039370m), 2);
            else
                return null;
        }

        internal static decimal? GetCelsiusValue(decimal? Fahrenheit)
        {
            if (Fahrenheit.HasValue)
                return decimal.Round(((Fahrenheit.Value - 32) / 1.8m), 2);
            else
                return null;
        }

        internal static decimal? GetFahrenheitValue(decimal? Celsius)
        {
            if (Celsius.HasValue)
                return decimal.Round(((Celsius.Value * 1.8m) + 32), 2);
            else
                return null;
        }

        internal static ValueTypes FixValuesRange(ref decimal? Avg, ref decimal? min, ref decimal? max)
        {
            if (min.HasValue && max.HasValue)
            {
                if (Avg.HasValue && ((min + max) / 2) != Avg)
                {
                    min = null;
                    max = null;
                    return ValueTypes.AvgOnly;
                }
                else if (min.Value == max.Value)
                {
                    min = null;
                    max = null;
                    return ValueTypes.AvgOnly;
                }
                else
                {
                    Avg = (min + max) / 2;
                    return ValueTypes.All;
                }
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
            else if (!Avg.HasValue)
            {
                return ValueTypes.None;
            }
            else
            {
                return ValueTypes.AvgOnly;
            }
        }



        #endregion
    }
}
