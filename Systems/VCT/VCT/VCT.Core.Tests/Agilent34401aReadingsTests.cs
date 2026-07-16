using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Pure interpretation logic for 34401A READ? values (over-range detection and the
    /// temperature-conversion decision).
    /// </summary>
    [TestClass]
    public class Agilent34401aReadingsTests
    {
        #region IsOverload

        [TestMethod]
        public void IsOverload_NormalValues_False()
        {
            Assert.IsFalse(Agilent34401aReadings.IsOverload(-1.7214e-05)); // ~ open-lead noise
            Assert.IsFalse(Agilent34401aReadings.IsOverload(0.0));
            Assert.IsFalse(Agilent34401aReadings.IsOverload(12345.678));
            Assert.IsFalse(Agilent34401aReadings.IsOverload(4.356e-03));
        }

        [TestMethod]
        public void IsOverload_34401aOverrangeSentinel_True()
        {
            Assert.IsTrue(Agilent34401aReadings.IsOverload(9.9e37));
            Assert.IsTrue(Agilent34401aReadings.IsOverload(-9.9e37));
        }

        [TestMethod]
        public void IsOverload_NaNOrInfinity_True()
        {
            Assert.IsTrue(Agilent34401aReadings.IsOverload(double.NaN));
            Assert.IsTrue(Agilent34401aReadings.IsOverload(double.PositiveInfinity));
            Assert.IsTrue(Agilent34401aReadings.IsOverload(double.NegativeInfinity));
        }

        #endregion

        #region RequiresTemperatureConversion

        [TestMethod]
        public void RequiresTemperatureConversion_RtdAndFrtd_True()
        {
            Assert.IsTrue(Agilent34401aReadings.RequiresTemperatureConversion(
                new SensorType { SensType = SensorType.SensorTypes.RTD }));
            Assert.IsTrue(Agilent34401aReadings.RequiresTemperatureConversion(
                new SensorType { SensType = SensorType.SensorTypes.FRTD }));
        }

        [TestMethod]
        public void RequiresTemperatureConversion_VdcNoneOrNull_False()
        {
            Assert.IsFalse(Agilent34401aReadings.RequiresTemperatureConversion(
                new SensorType
                {
                    MeasureType = SensorType.MeasureTypes.VDC,
                    SensType = SensorType.SensorTypes.None
                }));
            Assert.IsFalse(Agilent34401aReadings.RequiresTemperatureConversion(null));
        }

        #endregion
    }
}
