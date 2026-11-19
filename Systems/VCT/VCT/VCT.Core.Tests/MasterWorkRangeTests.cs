using ComServerBL.Hydra2.DAL.Calibration;
using Maba.DAL.BaseDAL.Records;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-831: a precision master's ITS-90 coefficients are only valid inside its working range
    /// (Jira 38168: 21-290, fitted over -195.7 to 23 degC, is about 87 degC off at 100 degC). The 34401A
    /// warns when the converted temperature leaves that range and keeps sending it (Jira 38172).
    /// </summary>
    [TestClass]
    public class MasterWorkRangeTests
    {
        /// <summary>21-214 as on STAGE: -80 to 200 degC.</summary>
        private static SensorCoefficients Sensor21_214(double? min = -80, double? max = 200) =>
            new SensorCoefficients(100.0018614, -0.0188349, 0.00064590173677, -0.01943119, -0.00032928408, 0.00022327774)
            {
                WorkRangeMin = min,
                WorkRangeMax = max,
            };

        [TestMethod]
        public void InsideTheRange_IsZero_EndsIncluded()
        {
            var sensor = Sensor21_214();

            Assert.AreEqual(0, sensor.CompareToWorkRange(25));
            Assert.AreEqual(0, sensor.CompareToWorkRange(-80));
            Assert.AreEqual(0, sensor.CompareToWorkRange(200));
        }

        [TestMethod]
        public void BelowAndAbove_AreMinusOneAndOne()
        {
            var sensor = Sensor21_214();

            Assert.AreEqual(-1, sensor.CompareToWorkRange(-80.001));
            Assert.AreEqual(1, sensor.CompareToWorkRange(200.001));
        }

        [TestMethod]
        public void NoRangeOnFile_IsNeverOutside()
        {
            Assert.AreEqual(0, Sensor21_214(null, null).CompareToWorkRange(500));
            Assert.AreEqual(0, Sensor21_214(-80, null).CompareToWorkRange(500), "one end alone is not a range");
            Assert.IsNull(Sensor21_214(null, null).WorkRangeText());
        }

        [TestMethod]
        public void ASecondRange_CountsAsInside_AndAGapAsAbove()
        {
            var sensor = Sensor21_214(-196, 23);
            sensor.WorkRangeMin2 = 100;
            sensor.WorkRangeMax2 = 300;

            Assert.AreEqual(0, sensor.CompareToWorkRange(150));
            Assert.AreEqual(1, sensor.CompareToWorkRange(50), "between the two ranges");
            Assert.AreEqual(-1, sensor.CompareToWorkRange(-197));
            Assert.AreEqual("-196 to 23 °C and 100 to 300 °C", sensor.WorkRangeText());
        }

        [TestMethod]
        public void RangeText_UsesAPointForDecimals()
        {
            Assert.AreEqual("-195.654 to 23.039 °C", Sensor21_214(-195.654, 23.039).WorkRangeText());
        }

        [TestMethod]
        public void TheMastersOwnRangeIsUsed()
        {
            var repository = new CalibrationRepository();
            repository.SetSensorCoefficients("21-214", Sensor21_214());
            var hc = new HydraCalculations(repository);

            Assert.AreEqual(1, hc.CompareToMasterWorkRange("21-214", 205, out var range));
            Assert.AreEqual("-80 to 200 degC", range, "ASCII: it goes to server.log");
            Assert.AreEqual(0, hc.CompareToMasterWorkRange("21-214", 100, out _));
        }

        [TestMethod]
        public void AMasterWithNoCoefficients_IsNotChecked()
        {
            var hc = new HydraCalculations(new CalibrationRepository());

            Assert.AreEqual(0, hc.CompareToMasterWorkRange("21-999", 500, out var range));
            Assert.IsNull(range);
        }

        [TestMethod]
        public void SwappedEnds_AreReadLowToHigh()
        {
            var sensor = Sensor21_214(200, -80);

            Assert.AreEqual(0, sensor.CompareToWorkRange(25));
            Assert.AreEqual(1, sensor.CompareToWorkRange(201));
            Assert.AreEqual("-80 to 200 °C", sensor.WorkRangeText());
        }

        [TestMethod]
        public void ANonFiniteTemperature_IsNeverOutside()
        {
            var sensor = Sensor21_214();

            Assert.AreEqual(0, sensor.CompareToWorkRange(double.NaN));
            Assert.AreEqual(0, sensor.CompareToWorkRange(double.PositiveInfinity));
        }

        [TestMethod]
        public void AMargin_NarrowsWhatCountsAsInside()
        {
            var sensor = Sensor21_214();

            Assert.AreEqual(0, sensor.CompareToWorkRange(199.95));
            Assert.AreEqual(1, sensor.CompareToWorkRange(199.95, 0.1));
            Assert.AreEqual(-1, sensor.CompareToWorkRange(-79.95, 0.1));
            Assert.AreEqual(0, sensor.CompareToWorkRange(199.85, 0.1));
        }

        [TestMethod]
        public void LogText_IsAscii()
        {
            Assert.AreEqual("-80 to 200 degC", Sensor21_214().WorkRangeText("degC"));
        }

        [TestMethod]
        public void AConversionThatIsNotANumber_IsWrongValue_NotAnOkReading()
        {
            // A4 this negative takes W - dW below zero at W = 0.5, and its sixth root is NaN.
            var broken = new SensorCoefficients(100, -1000, 0, 0, 0, 0);

            var result = HydraCalculations.ResistanceToTemperatureITS90(50, broken);

            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, result.Item2);
        }

        private static MasterWorkRangeMonitor Monitor()
        {
            var repository = new CalibrationRepository();
            repository.SetSensorCoefficients("21-214", Sensor21_214());
            return new MasterWorkRangeMonitor(new HydraCalculations(repository));
        }

        [TestMethod]
        public void Monitor_ABathSettledAtTheEnd_GivesOneExcursion()
        {
            var monitor = Monitor();

            Assert.AreEqual(MasterWorkRangeMonitor.NoChange, monitor.Observe("21-214", 199.998, out _));
            Assert.AreEqual(1, monitor.Observe("21-214", 200.002, out var range), "the excursion starts");
            Assert.AreEqual("-80 to 200 degC", range);
            foreach (var reading in new[] { 199.999, 200.001, 199.95, 200.003 })
                Assert.AreEqual(MasterWorkRangeMonitor.NoChange, monitor.Observe("21-214", reading, out _), reading.ToString());
            Assert.AreEqual(0, monitor.Observe("21-214", 199.85, out _), "clearly back inside ends it");
            Assert.AreEqual(1, monitor.Observe("21-214", 200.5, out _), "a new excursion is reported again");
        }

        [TestMethod]
        public void Monitor_GoingStraightToTheOtherSide_IsANewExcursion()
        {
            var monitor = Monitor();

            Assert.AreEqual(1, monitor.Observe("21-214", 250, out _));
            Assert.AreEqual(-1, monitor.Observe("21-214", -90, out _));
        }

        [TestMethod]
        public void Monitor_AResetOrAnotherMaster_ReportsAStillOutsideMasterAgain()
        {
            var monitor = Monitor();
            Assert.AreEqual(1, monitor.Observe("21-214", 250, out _));
            Assert.AreEqual(MasterWorkRangeMonitor.NoChange, monitor.Observe("21-214", 251, out _));

            monitor.Reset();
            Assert.AreEqual(1, monitor.Observe("21-214", 251, out _), "after a Confirm");

            Assert.AreEqual(MasterWorkRangeMonitor.NoChange, monitor.Observe("21-999", 500, out _), "no coefficients");
            Assert.AreEqual(1, monitor.Observe("21-214", 251, out _), "the master changed in between");
        }
    }
}
