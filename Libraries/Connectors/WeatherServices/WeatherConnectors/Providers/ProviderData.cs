using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers
{
    public class ProviderData
    {
        public JToken Data { set; get; }
        public string ProviderName { set; get; }

        public ProviderData(string _name, JToken _data)
        {
            ProviderName = _name;
            Data = _data;
        }
    }
}
