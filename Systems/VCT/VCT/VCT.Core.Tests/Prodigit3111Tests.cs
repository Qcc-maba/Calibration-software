using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the PRODIGIT 3111 command builders and reply interpretation. Every command and reply
    /// below is what the instrument actually answered when its command set was mapped on 2026-09-02
    /// (COM10, 115200 8-N-1) — no programming manual for this model could be found.
    /// </summary>
    [TestClass]
    public class Prodigit3111Tests
    {
        private static SensorType Sensor(SensorType.MeasureTypes type)
        {
            return new SensorType { MeasureType = type, SensType = SensorType.SensorTypes.None };
        }

        #region commands

        [TestMethod]
        public void Build_VerifiedQueries()
        {
            Assert.AreEqual("*IDN?", HydraProtocolHelper.Build_Prodigit_Identify().Command);
            Assert.AreEqual("VER?", HydraProtocolHelper.Build_Prodigit_Version().Command);
            Assert.AreEqual("MEAS:VOLT?", HydraProtocolHelper.Build_Prodigit_MeasureVoltage().Command);
            Assert.AreEqual("MEAS:CURR?", HydraProtocolHelper.Build_Prodigit_MeasureCurrent().Command);
            Assert.AreEqual("MEAS:POW?", HydraProtocolHelper.Build_Prodigit_MeasurePower().Command);
            Assert.AreEqual("LOAD?", HydraProtocolHelper.Build_Prodigit_QueryLoadState().Command);
            Assert.AreEqual("MODE?", HydraProtocolHelper.Build_Prodigit_QueryMode().Command);
            Assert.AreEqual("ERR?", HydraProtocolHelper.Build_Prodigit_ReadError().Command);
        }

        [TestMethod]
        public void EveryBuiltCommandIsAQuery_NothingCanArmTheLoad()
        {
            // This instrument sinks current. No builder may produce a command that arms it, so the
            // safety property is asserted rather than left to review.
            var commands = new[]
            {
                HydraProtocolHelper.Build_Prodigit_Identify().Command,
                HydraProtocolHelper.Build_Prodigit_Version().Command,
                HydraProtocolHelper.Build_Prodigit_MeasureVoltage().Command,
                HydraProtocolHelper.Build_Prodigit_MeasureCurrent().Command,
                HydraProtocolHelper.Build_Prodigit_MeasurePower().Command,
                HydraProtocolHelper.Build_Prodigit_QueryLoadState().Command,
                HydraProtocolHelper.Build_Prodigit_QueryMode().Command,
                HydraProtocolHelper.Build_Prodigit_ReadError().Command,
                HydraProtocolHelper.Build_Prodigit_Measure(Sensor(SensorType.MeasureTypes.Current)).Command,
            };

            foreach (var cmd in commands)
                StringAssert.EndsWith(cmd, "?", cmd + " must be a query");
        }

        [TestMethod]
        public void Build_Measure_FollowsTheConfiguredQuantity()
        {
            Assert.AreEqual("MEAS:VOLT?", HydraProtocolHelper.Build_Prodigit_Measure(Sensor(SensorType.MeasureTypes.VoltageDC)).Command);
            Assert.AreEqual("MEAS:CURR?", HydraProtocolHelper.Build_Prodigit_Measure(Sensor(SensorType.MeasureTypes.Current)).Command);
            Assert.AreEqual("MEAS:POW?", HydraProtocolHelper.Build_Prodigit_Measure(Sensor(SensorType.MeasureTypes.Power)).Command);
            // Unset or anything else falls back to voltage.
            Assert.AreEqual("MEAS:VOLT?", HydraProtocolHelper.Build_Prodigit_Measure(null).Command);
        }

        #endregion

        #region reply interpretation

        [TestMethod]
        public void TryParseMeasurement_ReadsTheSignedFixedPointReply()
        {
            double v;
            Assert.IsTrue(Prodigit3111Readings.TryParseMeasurement("+0.0000\r\n", out v));
            Assert.AreEqual(0.0, v, 1e-9);

            Assert.IsTrue(Prodigit3111Readings.TryParseMeasurement("-0.0000", out v));
            Assert.AreEqual(0.0, v, 1e-9);

            Assert.IsTrue(Prodigit3111Readings.TryParseMeasurement("+12.3450", out v));
            Assert.AreEqual(12.345, v, 1e-9);

            Assert.IsTrue(Prodigit3111Readings.TryParseMeasurement("0", out v)); // LOAD? / MODE?
            Assert.AreEqual(0.0, v, 1e-9);
        }

        [TestMethod]
        public void TryParseMeasurement_RejectsGarbageRatherThanReturningZero()
        {
            // 0 is a perfectly plausible reading on a load, so a failed parse must not become one.
            double v;
            Assert.IsFalse(Prodigit3111Readings.TryParseMeasurement("", out v));
            Assert.IsFalse(Prodigit3111Readings.TryParseMeasurement(null, out v));
            Assert.IsFalse(Prodigit3111Readings.TryParseMeasurement("PRODIGIT_3111", out v));
            Assert.IsFalse(Prodigit3111Readings.TryParseMeasurement("MF r0.2", out v));
        }

        [TestMethod]
        public void IsLoadOn_ReadsTheArmedState()
        {
            Assert.IsFalse(Prodigit3111Readings.IsLoadOn("0"));      // measured: load off
            Assert.IsTrue(Prodigit3111Readings.IsLoadOn("1"));
            Assert.IsFalse(Prodigit3111Readings.IsLoadOn(""));
            Assert.IsFalse(Prodigit3111Readings.IsLoadOn(null));
        }

        [TestMethod]
        public void IsPlausible_BoundsReadingsByTheRating()
        {
            // 80 V / 70 A / 350 W.
            Assert.IsTrue(Prodigit3111Readings.IsPlausible(12.0, Prodigit3111Readings.MaxVolts));
            Assert.IsTrue(Prodigit3111Readings.IsPlausible(-5.0, Prodigit3111Readings.MaxVolts));
            Assert.IsFalse(Prodigit3111Readings.IsPlausible(120.0, Prodigit3111Readings.MaxVolts));
            Assert.IsFalse(Prodigit3111Readings.IsPlausible(double.NaN, Prodigit3111Readings.MaxVolts));
            Assert.IsFalse(Prodigit3111Readings.IsPlausible(double.PositiveInfinity, Prodigit3111Readings.MaxVolts));
        }

        [TestMethod]
        public void RatedMaximumFor_MatchesTheQuantity()
        {
            Assert.AreEqual(Prodigit3111Readings.MaxVolts, Prodigit3111Readings.RatedMaximumFor(Sensor(SensorType.MeasureTypes.VoltageDC)));
            Assert.AreEqual(Prodigit3111Readings.MaxAmps, Prodigit3111Readings.RatedMaximumFor(Sensor(SensorType.MeasureTypes.Current)));
            Assert.AreEqual(Prodigit3111Readings.MaxWatts, Prodigit3111Readings.RatedMaximumFor(Sensor(SensorType.MeasureTypes.Power)));
            Assert.AreEqual(Prodigit3111Readings.MaxVolts, Prodigit3111Readings.RatedMaximumFor(null));
        }

        #endregion

        #region units

        [TestMethod]
        public void CurrentAndPower_HaveTheirOwnUnits()
        {
            Assert.AreEqual("Ampere", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Current)));
            Assert.AreEqual("Watt", HardwareBL_Settings.UnitsForSensor(Sensor(SensorType.MeasureTypes.Power)));
        }

        [TestMethod]
        public void TheLoadDefaultsToVolts()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual("Volt", s.DefaultUnitsForDeviceSN("PRODIGIT_3111"));
            Assert.AreSame(s.Prodigit3111, s.ResolveFamilyBySN("PRODIGIT_3111"));
        }

        #endregion
    }
}
