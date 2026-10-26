using ComServerBL.Hydra2.DAL.Calibration;
using Maba.DAL.BaseDAL.Records;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-831: the ITS-90 conversion uses the master's own coefficients (dbo.GetSensorCoefficients)
    /// instead of sensor 21-214's, which were hard-coded for every sensor.
    ///
    /// The expected temperatures are what the hard-coded version returned for 21-214, computed from
    /// that formula before the change - so 21-214, once its coefficients are on file, converts
    /// exactly as it did.
    /// </summary>
    [TestClass]
    public class Its90PerSensorCoefficientsTests
    {
        private const double Tolerance = 1e-9;

        private static readonly SensorCoefficients Sensor21_214 =
            new SensorCoefficients(100.0018614, -0.0188349, 0.00064590173677, -0.01943119, -0.00032928408, 0.00022327774);

        /// <summary>The repository the BLs build; its connection string points nowhere (app.config).</summary>
        private static HydraCalculations WithCoefficients(string mabaID, SensorCoefficients coefficients)
        {
            var repository = new CalibrationRepository();
            if (coefficients != null)
                repository.SetSensorCoefficients(mabaID, coefficients);
            return new HydraCalculations(repository);
        }

        [TestMethod]
        public void Sensor21_214_ConvertsAsTheHardCodedVersionDid()
        {
            var hc = WithCoefficients("21-214", Sensor21_214);

            AssertConverts(hc, "21-214", 80.0, -50.690183761153435);        // below 0 degC (W <= 1)
            AssertConverts(hc, "21-214", 100.0018614, 0.009999726840078438); // RTP: the triple point
            AssertConverts(hc, "21-214", 119.3, 49.71180283965036);         // above 0 degC (W > 1)
            AssertConverts(hc, "21-214", 138.5, 99.92710142039704);
        }

        [TestMethod]
        public void AnotherSensor_IsConvertedWithItsOwnCoefficients()
        {
            var other = new SensorCoefficients(99.98, 0, 0, 0, 0, 0);
            var hc = WithCoefficients("21-300", other);

            AssertConverts(hc, "21-300", 119.3, 48.821073210367366);
            Assert.AreNotEqual(49.71180283965036, hc.CalcResistanceToTemperatureITS90("21-300", 119.3).Item1, 0.1,
                "a sensor with its own coefficients must not get 21-214's temperature");
        }

        [TestMethod]
        public void NoCoefficientsOnFile_IsRefused_NotConvertedWith21_214s()
        {
            var hc = WithCoefficients("21-214", Sensor21_214);

            var result = hc.CalcResistanceToTemperatureITS90("21-999", 119.3);

            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, result.Item2);
            Assert.AreEqual(9999, result.Item1);
        }

        [TestMethod]
        public void NoMaster_IsRefused()
        {
            var hc = WithCoefficients("21-214", Sensor21_214);

            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, hc.CalcResistanceToTemperatureITS90(null, 119.3).Item2);
            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, hc.CalcResistanceToTemperatureITS90("", 119.3).Item2);
        }

        [TestMethod]
        public void OhmToCelsius_GoesThroughTheMastersCoefficients()
        {
            var hc = WithCoefficients("21-214", Sensor21_214);

            var known = hc.CalcConversionUnits(119.3, HydraCalculations.ConversionUnits.Ohm, HydraCalculations.ConversionUnits.Celsius, "21-214");
            var unknown = hc.CalcConversionUnits(119.3, HydraCalculations.ConversionUnits.Ohm, HydraCalculations.ConversionUnits.Celsius, "21-999");

            Assert.AreEqual(49.71180283965036, known.Item1, Tolerance);
            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, unknown.Item2);
        }

        [TestMethod]
        public void ZeroRTP_IsWrongValue()
        {
            var result = HydraCalculations.ResistanceToTemperatureITS90(100, new SensorCoefficients(0, 0, 0, 0, 0, 0));

            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, result.Item2);
        }

        private static void AssertConverts(HydraCalculations hc, string mabaID, double ohms, double expectedCelsius)
        {
            var result = hc.CalcResistanceToTemperatureITS90(mabaID, ohms);
            Assert.AreEqual(CalibrationRepository.ResultStatus.OK, result.Item2, $"{ohms} ohm");
            Assert.AreEqual(expectedCelsius, result.Item1, Tolerance, $"{ohms} ohm");
        }
    }
}
