using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.PETProcessing.AgricultureData
{
    public class AgricultureRecord
    {
        public const long DATETIME_UNIX_1970_1JAN = 621355968000000000;
        public DateTime RecordDate { get; set; }

        public long RecordDateT { get {  return ((RecordDate.Ticks - DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond); } }
        public string SID { get; set; }
        public string HottestMonth { get; set; }
        public string StationName { get; set; }

        /// ????
        public long ELV { get; set; } /// ????

        public Location location { set; get; }

        public Monthly_Values JAN { get; set; }

        public Monthly_Values FEB { get; set; }

        public Monthly_Values MAR { get; set; }

        public Monthly_Values APR { get; set; }

        public Monthly_Values MAY { get; set; }

        public Monthly_Values JUN { get; set; }

        public Monthly_Values JUL { get; set; }

        public Monthly_Values AUG { get; set; }

        public Monthly_Values SEP { get; set; }

        public Monthly_Values OCT { get; set; }

        public Monthly_Values NOV { get; set; }

        public Monthly_Values DEC { get; set; }

        public Summary_Values Daily_Summary { get; set; }

        public Summary_Values Total_Summary_Temp { get; set; }

        public Summary_Values Total_Summary_Humidity { get; set; }
    }


    

   


}
