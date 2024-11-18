using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather
{
    public class ForecastDataView
    {
        #region CONSTANTS

        public const int LAST_VERSION = 4;

        #endregion

        #region properties

        public int Version { get; set; }
        public long forecastDateT { get; set; }

        public DateTime ForecastDate
        {
            get { return new DateTime(forecastDateT); }
        }

        public int Year { get; set; }
        public int Month { get; set; }
        public int DayInMonth { get; set; }
        public DayOfWeek Day { get; set; }
        public string DayTitle
        {
            get
            {
                return ((DayOfWeek)(Day)).ToString();
            }
        }


        //Forecast
        public string Condition { get; set; }
        public IconDataView IconData { set; get; }

        public ThreeUnitsView Temperature { get; set; }

        //humidity
        public ThreeUnitsView Humidity { get; set; }

        public PrecipitationObject Prec_Inch { get; set; }

        public PrecipitationObject Prec_mm { get; set; }
        public PrecipitationObject Prec_PercentChance { get; set; }


        public string WindDirection { get; set; }
        public decimal WindSpeed_MPH { get; set; }

        public DateTime RecordDate
        {
            get { return new DateTime(RecordDateT); }
        }

        public long RecordDateT
        {
            get; set;
        }

        #endregion

        #region ctor

        public ForecastDataView()
        {

        }

        public ForecastDataView(ThreeUnitsView.TemperatureUnits Unit, Connectors.WeatherServices.Forecast.SingleDayData itemDay, DateTime RecordDate)
        {
            //dates
            RecordDateT = RecordDate.Ticks;
            forecastDateT = itemDay.date.Ticks;
            Year = itemDay.date.Year;
            Month = itemDay.date.Month;
            DayInMonth = itemDay.date.Day;
            Day = itemDay.date.DayOfWeek;

            Condition = itemDay.description;
            IconData = new IconDataView()
            {
                Code = itemDay.icon.Code,
                Day_Url = itemDay.icon.Day_Url,
                Night_Url = itemDay.icon.Night_Url,
                Provider_Url = itemDay.icon.Provider_Url
            };

            if (Unit == ThreeUnitsView.TemperatureUnits.Celsius)
            {
                Temperature = new ThreeUnitsView()
                {
                    UnitLabel = "C",
                    Avg = itemDay.Temp_Celsius.Avg ?? 0,
                    High = itemDay.Temp_Celsius.Max ?? 0,
                    Low = itemDay.Temp_Celsius.Min ?? 0,
                    ValueType = itemDay.Temp_Celsius.ValueType.ToString()
                };
            }
            else
            {
                Temperature = new ThreeUnitsView()
                {
                    UnitLabel = "F",
                    Avg = itemDay.Temp_Fahrenheit.Avg ?? 0,
                    High = itemDay.Temp_Fahrenheit.Max ?? 0,
                    Low = itemDay.Temp_Fahrenheit.Min ?? 0,
                    ValueType = itemDay.Temp_Fahrenheit.ValueType.ToString()
                };
            }

            this.Humidity = new ThreeUnitsView()
            {
                ValueType = itemDay.Humidity.ValueType.ToString(),
                Avg = itemDay.Humidity.Avg,
                High = itemDay.Humidity.Max,
                Low = itemDay.Humidity.Min,
                UnitLabel = "%"
            };

            this.Prec_Inch = new PrecipitationObject()
            {
                ValueType = itemDay.Prec_Inch.ValueType.ToString(),
                Avg = itemDay.Prec_Inch.Avg,
                Day = itemDay.Prec_Inch.Day,
                Night = itemDay.Prec_Inch.Night,
                UnitLabel = "In"
            };

            this.Prec_mm = new PrecipitationObject()
            {
                ValueType = itemDay.Prec_mm.ValueType.ToString(),
                Avg = itemDay.Prec_mm.Avg,
                Day = itemDay.Prec_mm.Day,
                Night = itemDay.Prec_mm.Night,
                UnitLabel = "mm"
            };

            this.Prec_PercentChance = new PrecipitationObject()
            {
                ValueType = itemDay.Prec_Percent.ValueType.ToString(),
                Avg = itemDay.Prec_Percent.Avg,
                Day = itemDay.Prec_Percent.Day,
                Night = itemDay.Prec_Percent.Night,
                UnitLabel = "%"
            };
        }

        #endregion
    }



}
