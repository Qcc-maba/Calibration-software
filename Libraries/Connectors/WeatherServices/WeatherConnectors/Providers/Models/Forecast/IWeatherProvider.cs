using Maba.Connectors.WeatherServices.Forecast;
using Maba.Connectors.WeatherServices.Providers.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices
{
    public interface IWeatherProvider
    {
        string ProviderName { get; }
        ForecastData GetForecast(decimal lat, decimal lon, int MaxDays, string units);
     
        string[] GetSupportedUnits();
    }
}
