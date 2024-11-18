using Maba.Connectors.WeatherServices.Providers.Models;
using Maba.Connectors.WeatherServices.Providers.Models.Current;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers
{
    public interface IWeatherProviderCurrentObservations
    {
        CurrentConditionsObservation GetCurrentObservations(decimal lat, decimal lon,string units);
    }
}
