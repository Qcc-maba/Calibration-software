using Maba.Connectors.WeatherServices.Providers.Models.Types;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.Providers.Models.Current
{
    public class CurrentConditionsData
    {
        /* Expiration time in UNIX seconds*/
        public long Expire_Time { set; get; }

        /* Time observation is valid*/
        public long Obs_Time { set; get; }
        /*
            Time observation is valid ... . in local, but at top of next UTC hour
        */
        public DateTime Obs_Time_Local { set; get; }

        public string DayOfWeek { set; get; }

        /**
      * 
          The direction from which the wind blows expressed in degrees.
          The magnetic direction varies from 0 to 359 degrees, where 0° indicates the North, 90° the East, 180° the South, 270° the West, and so forth.

      * */
        public int? WindDirection { set; get; }//wdir

        /***
         * 
            This field contains the cardinal direction from which the wind blows in an abbreviated form. Wind directions are always expressed as “from whence the wind blows” meaning that a North wind blows from North to South. If you face North in a North wind, the wind is at your face. Face southward and the North wind is at your back.
        **/
        public int? WindDirection_Cardinal { set; get; }//wdir_cardinal

        public IconData icon { set; get; }

        /**
      * A text description of the observed weather conditions at the reporting station
      * */
        public string DescriptionWeather { set; get; } //phrase_32char


        /**
        * 
            Descriptive sky cover - based on percentage of cloud cover

        * */
        public string DescriptionCloudCover { set; get; }//sky_cover

        /**
      * Cloud cover description code , =>SKC, CLR, SCT, FEW, BKN, OVC
      * */
        public string CloudCover { set; get; }//clds


        /**
        * Weather description qualifier terse phrase
        * */
        public string Description_Phrase { get; set; } //ptend_desc
        /**
         * Weather description qualifier short phrase 
         * 0 = steady, 
            1 = rising, 
            2 = falling, 
            3=rising rapidly, 
            4= falling rapidly
        * */
        public int? Phrase_Code { get; set; } //ptend_code

        /*This field contains the local time of the sunrise. It reflects any local daylight savings conventions.
        For a few Arctic and Antarctic regions, the Sunrise and Sunset data values may be the same (each with a value of 12:01am) 
        to reflect conditions where a sunrise or sunset does not occur.
         */
        public DateTime SunriseDate { get; set; } //sunrise

        /**This field contains the local time of the sunset.It reflects any local daylight savings conventions.
        For a few Arctic and Antarctic regions, the Sunrise and Sunset data values may be the same(each with a value of 12:01am) 
            to reflect conditions where a sunrise or sunset does not occur.
            **/

        public DateTime SunsetDate { get; set; } //sunset



        /**
       * Daytime or nighttime of the local apparent time of the location
       * */

        public DaytimeTypes Daytime { set; get; }//day_ind

        /**
        * 
         The temperature which air must be cooled at constant pressure to reach saturation. 
         The Dew Point is also an indirect measure of the humidity of the air. 
         The Dew Point will never exceed the Temperature.
          When the Dew Point and Temperature are equal, 
          clouds or fog will typically form. The closer the values of Temperature and Dew Point,
          the higher the relative humidity.

        * */
        public int? DewPoint { set; get; }//dewpt

        /**
        * 
            Wind Speed.
            The wind is treated as a vector; hence, winds must have direction and magnitude (speed). 
            The wind information reported in the hourly current conditions corresponds to a 10-minute average called the sustained wind speed.
            Sudden or brief variations in the wind speed are known as “wind gusts” and are reported in a separate data field.
            Wind directions are always expressed as "from whence the wind blows" meaning that a North wind blows from North to South. 
            If you face North in a North wind the wind is at your face. Face southward and the North wind is at your back.

        * */
        public int? WindSpeed { set; get; }//wspd

        /**
         * 
            This data field contains information about sudden and temporary variations of the average Wind Speed.
            The report always shows the maximum wind gust speed recorded during the observation period.
            It is a required display field if Wind Speed is shown. The speed of the gust can be expressed in miles per hour or kilometers per hour.

         */

        public int? WindSpeedAverage { set; get; }//gust
        //average 
        /**
       
      
        * 
            The horizontal visibility at the observation point. 
            Visibilities can be reported as fractional values particularly when visibility is less than 2 miles.
            Visibilities greater than 10 statute miles(16.1 kilometers) which are considered “unlimited” are reported as “999” in your feed.
            You can also find visibility values that equal zero. This occurrence is not wrong.
            Dense fogs and heavy snows can produce values near zero. 
            Fog, smoke, heavy rain and other weather phenomena can reduce visibility to near zero miles or kilometers.

        * */
        public double? Visibilities { set; get; }//vis

        /**
         * The relative humidity of the air, which is defined as the ratio of the amount of water vapor in the air to the amount
         *  of vapor required to bring the air to saturation at a constant temperature. 
         * Relative humidity is always expressed as a percentage.
        * */

        public decimal? AvgHumidity { set; get; } // rh


        /**
         * 
         * */

        /**
         * The temperature of the air, 
         * at the time of the observation, measured by a thermometer 1.5 meters (4.5 feet) above the ground that is shaded from the other elements.
         * */
        public UnitObject Temp_Fahrenheit { get; set; } //temp
        /**
        * 
         * */
        public UnitObject Temp_Celsius { get; set; }



        /**
        * Precipitation amount in the last rolling 24 hour period
        * */

        public SumPeriod Prec_Inch { get; set; }

        public SumPeriod Prec_mm { get; set; }

        public SumPeriod Snow_Inch { get; set; }

        public SumPeriod Snow_mm { get; set; }

        /**
         * arometric pressure is the pressure exerted by the atmosphere at the earth's surface, 
         * due to the weight of the air.  This value is read directly from an instrument called a
         *  mercury barometer and its units are expressed in millibars (equivalent to HectoPascals).
         * */
        public double? Pressure { set; get; }//pchange

       
    }
}
