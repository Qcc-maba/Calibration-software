using Maba.Connectors.WeatherServices.Providers.Models;
using Maba.Connectors.WeatherServices.Providers.Models.Types;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.History
{
    
    public class HistoryDayData
    {

        /**
        *  Observation station ID
        * */
        public string StationID { set; get; }

        /**
        *  Observation station name
        * */
        public string StationName { set; get; }

        /**
         * Daytime or nighttime of the local apparent time of the location
         * */
        public DaytimeTypes Daytime { set; get; }
        /**
         * Absolute expiration time and used to implement a common, 
         * system wide method of data and cache expiration.
         * */
        public DateTime date { set; get; }
        /**
         * 
         * */
        public long dt { set; get; }
        /**
        * 
         The temperature which air must be cooled at constant pressure to reach saturation. 
         The Dew Point is also an indirect measure of the humidity of the air. 
         The Dew Point will never exceed the Temperature.
          When the Dew Point and Temperature are equal, 
          clouds or fog will typically form. The closer the values of Temperature and Dew Point,
          the higher the relative humidity.

        * */
        public int? DewPoint { set; get; }
        /**
        * A text description of the observed weather conditions at the reporting station
        * */
        public string DescriptionWeather { set; get; }
        /**
        * Weather description qualifier code
        * */

        public string Description_Qualifier { set; get; }
        /**
        * Weather description qualifier severity
        * */

        public int? Description_Rank { set; get; }
        /**
        * 
            Wind Speed.
            The wind is treated as a vector; hence, winds must have direction and magnitude (speed). 
            The wind information reported in the hourly current conditions corresponds to a 10-minute average called the sustained wind speed.
            Sudden or brief variations in the wind speed are known as “wind gusts” and are reported in a separate data field.
            Wind directions are always expressed as "from whence the wind blows" meaning that a North wind blows from North to South. 
            If you face North in a North wind the wind is at your face. Face southward and the North wind is at your back.

        * */
        public int? WindSpeed { set; get; }
        /**
        * 
            The direction from which the wind blows expressed in degrees.
            The magnetic direction varies from 0 to 359 degrees, where 0° indicates the North, 90° the East, 180° the South, 270° the West, and so forth.

        * */
        public int? WindDirection { set; get; }
        /**
        * Cloud cover description code , =>SKC, CLR, SCT, FEW, BKN, OVC
        * */
        public string CloudCover { set; get; }
        /**
        * 
            The horizontal visibility at the observation point. 
            Visibilities can be reported as fractional values particularly when visibility is less than 2 miles.
            Visibilities greater than 10 statute miles(16.1 kilometers) which are considered “unlimited” are reported as “999” in your feed.
            You can also find visibility values that equal zero. This occurrence is not wrong.
            Dense fogs and heavy snows can produce values near zero. 
            Fog, smoke, heavy rain and other weather phenomena can reduce visibility to near zero miles or kilometers.

        * */
        public double? Visibilities { set; get; }
        /**
       * 
       * */
        //Temp
        /**
         * The relative humidity of the air, which is defined as the ratio of the amount of water vapor in the air to the amount
         *  of vapor required to bring the air to saturation at a constant temperature. 
         * Relative humidity is always expressed as a percentage.
        * */

        public decimal? AvgHumidity { set; get; }

        /**
         * 
         * */
        public IconData icon { set; get; }
        /**
         * The temperature of the air, 
         * at the time of the observation, measured by a thermometer 1.5 meters (4.5 feet) above the ground that is shaded from the other elements.
         * */
        public UnitObject Temp_Fahrenheit { get; set; }
        /**
        * 
         * */
        public UnitObject Temp_Celsius{ get; set; }

        /**
        * Precipitation amount in the last rolling 24 hour period
        * */

        public SumUnitObject Prec_Inch { get; set; }

        public SumUnitObject Prec_mm { get; set; }

        public SumUnitObject Snow_Inch { get; set; }

        public SumUnitObject Snow_mm { get; set; }

        /**
         * arometric pressure is the pressure exerted by the atmosphere at the earth's surface, 
         * due to the weight of the air.  This value is read directly from an instrument called a
         *  mercury barometer and its units are expressed in millibars (equivalent to HectoPascals).
         * */
        public double? Pressure { set; get; }

        /**
         * Weather description qualifier terse phrase
         * */
        public string Description_Phrase { get; set; }
        /**
         * Weather description qualifier short phrase 
        * */
        public string Description_Phrase2 { get; set; }
        /**
        * A phrase describing the change in the barometric pressure reading over the last hour. 
        * */
        public string Pressure_desc { get; set; }
        /**
        * The change in the barometric pressure reading over the last hour expressed as an integer. 
        * */
        public int? Pressure_tend { get; set; }

        public HistoryDayData()
        {

        }



    }


   

}
