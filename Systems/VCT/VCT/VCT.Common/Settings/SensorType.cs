using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Settings
{
    public class SensorType
    {
        #region Enum
        public enum ThermocoupleTypes
        {
            //J = 0,
            K = 1,
            //E = 2,
            T = 3,
            //N = 4,
            R = 5,
            //S = 6,
            //B = 7,
            //C = 8,
        }

        public enum RTDType
        {
            PT100,
            PT25,
        }

        public enum MeasureTypes
        {
            None = -1,
            TEMP = 0,
            VDC = 1,
            Resistance = 2,
            Dew = 3,
            Humidity = 4,
        }

        public enum SensorTypes
        {
            None = -1,
            TCouple = 0,
            RTD = 1,
            FRTD = 2,
        }

        #endregion

        #region Members
        public MeasureTypes MeasureType = MeasureTypes.None;
        public ThermocoupleTypes ThermocoupleType { get; set; }
        public SensorTypes SensType = SensorTypes.None;
        public int numbertOfWires
        {
            get { return this.SensType == SensorTypes.FRTD ? 4 : 2; }
            set;
        }

        #endregion
    }
}