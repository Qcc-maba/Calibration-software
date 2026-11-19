using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Maba.DAL.BaseDAL.Records
{
    /// <summary>
    /// One precision sensor's ITS-90 coefficients, as dbo.GetSensorCoefficients returns them
    /// (MBA-816, MBA-831). RTP is the sensor's resistance at the triple point of water; A4/B4 its
    /// deviation function below 0 degC, A7/B7/C7 above it. Zeros for a range the sensor was not
    /// calibrated in.
    /// </summary>
    public class SensorCoefficients
    {
        #region Members
        public double RTP { get; set; }
        public double A4 { get; set; }
        public double B4 { get; set; }
        public double A7 { get; set; }
        public double B7 { get; set; }
        public double C7 { get; set; }

        /// <summary>
        /// MBA-831: the sensor's working range in degC (WorkRangeMin/Max), and its second range where it
        /// has one. The coefficients are only valid inside it: outside, the converted temperature can be
        /// off by degrees (Jira 38168). Null when no range in degC is on file.
        /// </summary>
        public double? WorkRangeMin { get; set; }
        public double? WorkRangeMax { get; set; }
        public double? WorkRangeMin2 { get; set; }
        public double? WorkRangeMax2 { get; set; }
        #endregion

        public SensorCoefficients()
        {

        }

        public SensorCoefficients(double rtp, double a4, double b4, double a7, double b7, double c7)
        {
            this.RTP = rtp;
            this.A4 = a4;
            this.B4 = b4;
            this.A7 = a7;
            this.B7 = b7;
            this.C7 = c7;
        }

        /// <summary>The ranges with both ends on file, lowest first.</summary>
        private List<KeyValuePair<double, double>> WorkRanges()
        {
            var ranges = new List<KeyValuePair<double, double>>();
            if (WorkRangeMin.HasValue && WorkRangeMax.HasValue)
                ranges.Add(new KeyValuePair<double, double>(WorkRangeMin.Value, WorkRangeMax.Value));
            if (WorkRangeMin2.HasValue && WorkRangeMax2.HasValue)
                ranges.Add(new KeyValuePair<double, double>(WorkRangeMin2.Value, WorkRangeMax2.Value));
            return ranges.OrderBy(r => r.Key).ToList();
        }

        /// <summary>
        /// MBA-831: where <paramref name="celsius"/> lies against the working range. 0 inside it, or when no
        /// range is on file; -1 below the lowest range; +1 otherwise (above it, or between two ranges).
        /// The ends are inside.
        /// </summary>
        public int CompareToWorkRange(double celsius)
        {
            var ranges = WorkRanges();
            if (ranges.Count == 0 || ranges.Any(r => celsius >= r.Key && celsius <= r.Value))
                return 0;
            return celsius < ranges[0].Key ? -1 : 1;
        }

        /// <summary>The working range as text ("-80 to 200", then the degree sign and C), or null when none is on file.</summary>
        public string WorkRangeText()
        {
            var ranges = WorkRanges();
            if (ranges.Count == 0)
                return null;
            return string.Join(" and ", ranges.Select(r => string.Format(CultureInfo.InvariantCulture,
                "{0:0.###} to {1:0.###} °C", r.Key, r.Value)));
        }
    }
}
