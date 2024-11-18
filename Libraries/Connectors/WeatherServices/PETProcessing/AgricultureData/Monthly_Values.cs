using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.PETProcessing.AgricultureData
{
   public  class Monthly_Values
    {
        public string TempUnitsType { set; get; }
        public int MonthOrderNumber { set; get; }
        public int DaysNumber { set; get; }
        public double DailyPET { set; get; }
        public double MAXPET { set; get; }
        public Summary_Values Humidity { set; get; }
        public Summary_Values Temp { set; get; }
        public int ObservationDay { set; get; }

        public string PETUnitsType { set; get; }
    }
}
