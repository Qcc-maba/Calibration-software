using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Extentions
{
    public static class JTokenExtentions
    {
        public static decimal? Convert(this JToken token)
        {
            return Convert(token, null);
        }

        public static int? Convertint(this JToken token)
        {
            return (int?)Convert(token, null);
        }

     
        public static decimal? Convert(this JToken token, decimal? DefaultValue)
        {
            var str = token.Value<string>();
            decimal d = 0;

            return decimal.TryParse(str, out d) ? d : DefaultValue;
        }
    }
}
