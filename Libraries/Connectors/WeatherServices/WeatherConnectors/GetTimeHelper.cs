using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices
{
    public static class GetTimeHelper
    {
        private static readonly DateTime UnixEpoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        public static DateTime ToDateTime(long _input)
        {
            return UnixEpoch.AddSeconds(_input);
        }

        public static DateTime ToDateTime_Milliseconds(long _input)
        {
            return UnixEpoch.AddMilliseconds(_input);
        }

        public static long To_Milliseconds(DateTime _input)
        {
            return (long)(TimeSpan.FromTicks(_input.Ticks).TotalMilliseconds - TimeSpan.FromTicks(UnixEpoch.Ticks).TotalMilliseconds);
        }

        public static string ToUTCString(DateTime _input)
        {
            var milliseconds = _input.ToUniversalTime().Subtract(UnixEpoch).TotalSeconds;
            return Convert.ToInt64(milliseconds).ToString();
        }
    }
}
