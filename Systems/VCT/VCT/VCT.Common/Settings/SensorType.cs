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
            /// <summary>
            /// NOT "volts". Legacy convention: the instrument reads a resistance which
            /// HydraCalculations.ProcessResults converts to a temperature via ITS-90
            /// (CalcResistanceToTemperatureITS90) and reports as Celsius. The 34401A is configured
            /// this way. Use <see cref="VoltageDC"/> for an instrument that genuinely reports volts.
            /// </summary>
            VDC = 1,
            Resistance = 2,
            Dew = 3,
            Humidity = 4,
            // Oscilloscope quantities (Keysight EDUX1002A). Appended with explicit values so
            // existing HydraBL_Settings.json files, which store the enum as an int, keep their meaning.
            VoltagePP = 5,
            VoltageRMS = 6,
            Frequency = 7,
            /// <summary>Genuine DC volts, as an oscilloscope or DMM reports them - unlike <see cref="VDC"/>.</summary>
            VoltageDC = 8,
            /// <summary>Current in amperes (an electronic load's sink current).</summary>
            Current = 9,
            /// <summary>Power in watts.</summary>
            Power = 10,
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
        }

        #endregion
    }
}