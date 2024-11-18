using Nest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;


namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.Models
{
    public class ForecastDataLog<T>
    {
        #region CONSTANTS

        private const string MESSAGE_ID__DATE_FORMAT = "yyMMddHHmmss";

        #endregion

        public T ForecastData { get; set; }

        public Location Location { set; get; }

        public DateTime RecordDate { get; set; }

        public long RecordDateT { get; set; }

        public string ForecastID { get; set; }

        public string DistanceFromForecast { get; set; }


        public ForecastDataLog()
        {

        }

        public static string HashLocation(Location location)
        {
            return String.Format("{0}.{1}",
                                Math.Truncate(Math.Sqrt((double)location.lat + 50)),
                                Math.Truncate(Math.Sqrt((double)location.lon + 50)));
        }

        public static ForecastDataLog<T> Create(DateTime RecordDate, Location location, T forecastData)
        {
            var forecast = new ForecastDataLog<T>()
            {
                RecordDate = RecordDate,
                Location = location,
                ForecastID = $"{HashLocation(location)}-{Math.Truncate(location.lat * 100)}{Math.Truncate(location.lon * 100)}-{RecordDate.ToString(MESSAGE_ID__DATE_FORMAT)}-{Guid.NewGuid().ToString().Substring(0, 5)}",
                ForecastData = forecastData
            };

            return forecast;
        }


        public override string ToString()
        {
            return $"Forecast:{this.RecordDate.ToString("yyMMdd:HHmm")} [{Location.lat}.{Location.lon}]";
        }
    }
}
