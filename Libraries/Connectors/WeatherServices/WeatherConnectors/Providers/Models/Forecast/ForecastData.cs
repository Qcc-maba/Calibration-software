using Maba.Connectors.WeatherServices;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Forecast
{
    public class ForecastData
    {
        public bool IsValid { get; set; }
        public Location location { set; get; }
        public int forecastDays { set; get; }
        public object Data { set; get; }
        public SingleDayData[] forecastList { set; get; }
        public Maba.Connectors.WeatherServices.Providers.ProviderData providerData { set; get; }
    }
}
