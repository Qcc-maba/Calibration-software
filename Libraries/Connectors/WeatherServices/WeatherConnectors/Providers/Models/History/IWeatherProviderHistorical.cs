using Maba.Connectors.WeatherServices.Providers.Models;
using Maba.Connectors.WeatherServices.Providers.Models.History;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers
{
    public interface IWeatherProviderHistorical
    {
        ObservationsData GetHistorical(decimal lat, decimal lon, DateTime startDate, DateTime? endDate, string units);
    }
}
