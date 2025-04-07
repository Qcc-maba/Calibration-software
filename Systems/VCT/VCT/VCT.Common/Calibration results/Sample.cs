using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static Maba.VCT.Common.Calibration_results.Sample;

namespace Maba.VCT.Common.Calibration_results
{
    public class Sample
    {
        #region Enum
        public enum Units
        {
            Celsius,
            Humidity
        }

        #endregion

        #region Members

        public int ChannelNumber { get; set; }
        public DateTime SampleDate { get; set; }
        public double Value { get; set; }
        public double ValueBeforeCorrection { get; set; }
        public double SecondValue { get; set; }
        public double SecondValueBeforeCorrection { get; set; }
        public double TotalResults { get; set; }
        public Units FirstUnit { get; set; }
        public Units SecondUnit { get; set; }
        public int Alert { get; set; }
        public int SecondAlert { get; set; }

        #endregion

        public Sample(double value, double valBefore, int alert, int channelNum, Units units)
        {
            SampleDate = DateTime.Now;
            Value = value;
            FirstUnit = units;
            ChannelNumber = channelNum;
            ValueBeforeCorrection = valBefore;
            Alert = alert;
        }
        public Sample(double value, double valBefore, int alert, int channelNum, Units units, double secondValue, Units secondUnits, double results) : this(value, valBefore, alert, channelNum, units)
        {

            SecondValue = secondValue;
            SecondValue =secondValue;
            TotalResults = results;
        }
    }
}
