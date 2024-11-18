using Maba.Connectors.WeatherServices.History;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers.Models.History
{
    public class ObservationsData
    {
        public bool IsValid { get; set; }
        public Location location { set; get; }
        public int historyDays { set; get; }
        public object Data { set; get; }
        public HistoryDayData[] historyData { set; get; }
        public Maba.Connectors.WeatherServices.Providers.ProviderData providerData { set; get; }
    }
}
