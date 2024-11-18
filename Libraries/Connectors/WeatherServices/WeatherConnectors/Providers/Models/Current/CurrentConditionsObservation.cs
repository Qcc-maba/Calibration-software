using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers.Models.Current
{
    public class CurrentConditionsObservation
    {
        public bool IsValid { get; set; }
        public Location location { set; get; }

     
        public object Data { set; get; }
        public CurrentConditionsData ObservationsData { set; get; }
        public Maba.Connectors.WeatherServices.Providers.ProviderData providerData { set; get; }
    }
}
