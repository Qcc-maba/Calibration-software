using Maba.Connectors.WeatherServices.Providers.Models;
using Maba.Connectors.WeatherServices.Providers.Models.Forecast;
using Maba.Connectors.WeatherServices.Providers.Models.Types;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Forecast
{

    public class SingleDayData
    {
        public DateTime date { set; get; }
        public long dt { set; get; }
        public int DayNum { set; get; }

        public string description { set; get; }
        public IconData icon { set; get; }

        public UnitObject Humidity { get; set; }

        public UnitObject Temp_Fahrenheit { get; set; }

        public UnitObject Temp_Celsius { get; set; }

        public PrecipitationObject Prec_Inch { get; set; }

        public PrecipitationObject Prec_mm { get; set; }
        public PrecipitationObject Prec_Percent { get; set; }
    }
}
