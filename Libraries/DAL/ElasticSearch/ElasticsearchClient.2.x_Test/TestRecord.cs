using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Connectors.Elasticsearch.Testing
{
    public class TestRecord
    {
        public const long DATETIME_UNIX_1970_1JAN = 621355968000000000;

        public string ID { get; set; }
        public DateTime RecordDate { get; set; }
        public long RecordDateT { get; set; }

        public DateTime CreationDate { get; set; }
        public string name { get; set; }
        public long Number1 { get; set; }
        public long Number2 { get; set; }
        public long Number3_SortDown { get; set; }
        public long Number3_SortUp { get; set; }
        public string data { get; set; }
        public Location Location { get; set; }

        internal double Distance { get; set; }

        public TestRecord(DateTime d)
        {
            RecordDate = d;
            RecordDateT = (d.Ticks - DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond;

        }

        public override string ToString()
        {
            return Location == null ? "" : $"{RecordDate.ToString("dd MMM yy HHmmss")}-{RecordDate.Ticks}-{Location.lat}.{Location.lon}";
        }

    }

    public class Location
    {
        public double lat { get; set; }
        public double lon { get; set; }

    }
}
