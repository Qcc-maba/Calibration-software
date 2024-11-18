using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary.Converters
{
    public class DateTimeUNIXConvertor : DateTimeConverterBase
    {
        public const long Point_1970_Ticks = 621355968000000000;

        #region ctor

        public DateTimeUNIXConvertor()
        {
        }

        #endregion

        #region DateTimeConverterBase members

        public override object ReadJson(JsonReader reader, Type objectType, object existingValue, JsonSerializer serializer)
        {
            if (reader.Value == null && objectType.IsGenericType && objectType.GetGenericTypeDefinition() == typeof(Nullable<>))
            {
                return null;
            }
            string value = reader.Value.ToString();

            if (String.IsNullOrEmpty(value))
            {
                return null;
            }

            if (value[0] == 'T')
            {
                return DateTime.Parse(value.Substring(1));
            }
            else
            {
                return new DateTime(Point_1970_Ticks + long.Parse(value.ToString()) * TimeSpan.TicksPerMillisecond);
            }
        }

        public override void WriteJson(JsonWriter writer, object value, JsonSerializer serializer)
        {
            var d = ((DateTime)value).Ticks;
            if (d <= Point_1970_Ticks)
            {
                writer.WriteValue(0);
            }
            else
            {
                writer.WriteValue((d - Point_1970_Ticks) / TimeSpan.TicksPerMillisecond);
            }
        }

        #endregion
    }
}
