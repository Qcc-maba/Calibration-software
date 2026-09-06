using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// The units a LoggerData broadcast carries when the web app has associated no sensor. These used
    /// to be a flat "Celsius" for every instrument; they now follow what the device measures.
    /// </summary>
    [TestClass]
    public class DefaultMeasurementUnitsTests
    {
        private static SensorType Sensor(SensorType.MeasureTypes measure,
                                         SensorType.SensorTypes sensor = SensorType.SensorTypes.None)
        {
            return new SensorType { MeasureType = measure, SensType = sensor };
        }

        #region per sensor configuration

        [TestMethod]
        public void Electrical_Quantities_ReportVolts()
        {
            Assert.AreEqual("Volt", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.VoltagePP)));
            Assert.AreEqual("Volt", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.VoltageRMS)));
            Assert.AreEqual("Volt", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.VoltageDC)));
        }

        [TestMethod]
        public void LegacyVdc_IsATemperature_NotVolts()
        {
            // The name is misleading: HydraCalculations.ProcessResults sends VDC through
            // CalcResistanceToTemperatureITS90 and emits Celsius. Mapping it to "Volt" would have
            // mislabelled every legacy device configured this way, the 34401A included.
            Assert.AreEqual("Celsius", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.VDC)));
            Assert.AreEqual("Celsius",
                HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.VDC, SensorType.SensorTypes.None)));
        }

        [TestMethod]
        public void Frequency_ReportsHertz()
        {
            Assert.AreEqual("Hertz", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Frequency)));
        }

        [TestMethod]
        public void Resistance_ReportsOhm()
        {
            Assert.AreEqual("Ohm", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Resistance)));
        }

        [TestMethod]
        public void Temperature_AndDewPoint_ReportCelsius()
        {
            Assert.AreEqual("Celsius", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.TEMP)));
            Assert.AreEqual("Celsius", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Dew)));
        }

        [TestMethod]
        public void Humidity_ReportsTheTemperatureItBroadcastsAsItsPrimaryValue()
        {
            // ProcessResults puts temperature in the primary value and humidity in the second one;
            // the LoggerData broadcast carries the primary.
            Assert.AreEqual("Celsius", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Humidity)));
        }

        [TestMethod]
        public void RtdAndThermocouple_ReportCelsius_EvenWhenTheMeasureTypeIsElectrical()
        {
            // A temperature probe wins over whatever the MeasureType claims: the BL converts the
            // reading to degrees before broadcasting, so the value the app receives is a temperature
            // even when the quantity on the wire is volts or ohms.
            Assert.AreEqual("Celsius",
                HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.VoltageDC, SensorType.SensorTypes.FRTD)));
            Assert.AreEqual("Celsius",
                HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Resistance, SensorType.SensorTypes.RTD)));
            Assert.AreEqual("Celsius",
                HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.TEMP, SensorType.SensorTypes.TCouple)));
        }

        [TestMethod]
        public void UnsetSensor_KeepsTheHistoricalCelsiusDefault()
        {
            Assert.AreEqual("Celsius", HardwareBL_Settings.UnitsForSensor(null));
            Assert.AreEqual("Celsius", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.None)));
        }

        #endregion

        #region SN -> family resolution

        [TestMethod]
        public void ResolveFamilyBySN_MatchesTheTokensTheBlCoresClaimBy()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();

            Assert.AreSame(s.Hydra2type, s.ResolveFamilyBySN("FLUKE,2625A"));
            Assert.AreSame(s.Hydra3type, s.ResolveFamilyBySN("FLUKE,2638A"));
            Assert.AreSame(s.Agilent, s.ResolveFamilyBySN("HEWLETT-PACKARD"));
            Assert.AreSame(s.Edux1002a, s.ResolveFamilyBySN("EDUX1002A"));
            Assert.AreSame(s.Optidew, s.ResolveFamilyBySN("Optidew"));
            Assert.AreSame(s.Instek, s.ResolveFamilyBySN("Instek"));
        }

        [TestMethod]
        public void ResolveFamilyBySN_UnknownDevice_HasNoFamily()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();

            Assert.IsNull(s.ResolveFamilyBySN("something-else"));
            Assert.IsNull(s.ResolveFamilyBySN(""));
            Assert.IsNull(s.ResolveFamilyBySN(null));
        }

        #endregion

        #region end result per device

        [TestMethod]
        public void Oscilloscope_DefaultsToVolts()
        {
            // The point of the change: a scope must not report volts labelled as Celsius.
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual("Volt", s.DefaultUnitsForDeviceSN("EDUX1002A"));
        }

        [TestMethod]
        public void TemperatureLoggers_StillDefaultToCelsius()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();

            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("FLUKE,2625A"));
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("FLUKE,2638A"));
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("Instek"));
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("Optidew"));
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("HEWLETT-PACKARD")); // VDC = resistance -> temperature
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("TTI-22"));          // PRT bridge
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("TAU"));             // Additel, PT100 scanner
        }

        [TestMethod]
        public void Calibrator_DefaultsToVolts_EvenWithoutAFamilyBucket()
        {
            // The 9100 is a source, not a logger, so it has no HardwareBL_Settings entry.
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual("Volt", s.DefaultUnitsForDeviceSN("Datron9100"));
        }

        [TestMethod]
        public void UnknownDevice_KeepsTheHistoricalCelsiusDefault()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual("Celsius", s.DefaultUnitsForDeviceSN("brand-new-instrument"));
        }

        #endregion
    }
}
