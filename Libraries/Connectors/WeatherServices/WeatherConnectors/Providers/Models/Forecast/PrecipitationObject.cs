using Maba.Connectors.WeatherServices.Providers.Models.Types;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers.Models.Forecast
{
    public class PrecipitationObject
    {
        public ValueTypes ValueType { set; get; }

        public decimal? Night { set; get; }
        public decimal? Day { set; get; }
        public decimal? Avg { set; get; }
    }
}
