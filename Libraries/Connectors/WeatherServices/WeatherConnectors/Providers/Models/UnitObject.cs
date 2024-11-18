using Maba.Connectors.WeatherServices.Providers.Models.Types;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers.Models
{
    public class UnitObject
    {
        public ValueTypes ValueType { set; get; }
        public decimal? Max { get; set; }
        public decimal? Avg { get; set; }
        public decimal? Min { get; set; }
    }
}
