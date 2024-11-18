using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers.Models.Current
{
    public class SumPeriod
    {
        public decimal? Hour_1 { set; get; }
        public decimal? Hour_6 { set; get; }
        public decimal? Hour_24 { set; get; }
        public decimal? Day_2 { set; get; }
        public decimal? Day_3 { set; get; }
        public decimal? Day_7 { set; get; }
        public decimal? Monthly { set; get; }
        public decimal? Season { set; get; }
        public decimal? Yearly { set; get; }
    }
}
