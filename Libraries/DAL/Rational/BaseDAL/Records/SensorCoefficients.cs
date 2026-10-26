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
    }
}
