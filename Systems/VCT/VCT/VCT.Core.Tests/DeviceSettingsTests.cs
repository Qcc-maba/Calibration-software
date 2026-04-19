using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Core;

namespace Galcon.VCT.Core.Tests
{
    [TestClass]
    public class DeviceSettingsTests
    {
        #region Constructor / Default Values

        [TestMethod]
        public void DeviceSettings_DefaultIdentificationType_IsIDN()
        {
            var settings = new DeviceSettings();

            Assert.AreEqual(DeviceSettings.IdentificationTypes.IDN, settings.IdentificationType);
        }

        [TestMethod]
        public void DeviceSettings_DefaultSessionRequestTimeout_IsOneMinute()
        {
            var settings = new DeviceSettings();

            Assert.AreEqual(TimeSpan.FromMinutes(1), settings.SessionRequestTimeout_TimeSpan);
        }

        [TestMethod]
        public void DeviceSettings_DefaultKeepAliveTimeout_IsTwoMinutes()
        {
            var settings = new DeviceSettings();

            Assert.AreEqual(TimeSpan.FromMinutes(2), settings.KeepAlive_RXTimeout_TimeSpan);
        }

        [TestMethod]
        public void DeviceSettings_DefaultClocksDeviation_IsFiveSeconds()
        {
            var settings = new DeviceSettings();

            Assert.AreEqual(TimeSpan.FromSeconds(5), settings.ClocksDeviation_TimeSpan);
        }

        [TestMethod]
        public void DeviceSettings_DefaultClocksDeviationMaxAttempts_Is10()
        {
            var settings = new DeviceSettings();

            Assert.AreEqual(10, settings.ClocksDeviation_MaxAttempts);
        }

        [TestMethod]
        public void DeviceSettings_DefaultIdentificationPacket_IsNotNull()
        {
            var settings = new DeviceSettings();

            Assert.IsNotNull(settings.IdentificationPacket);
        }

        [TestMethod]
        public void DeviceSettings_Constructor_IDN_MatchesBuildIdPacket()
        {
            var settings = new DeviceSettings(DeviceSettings.IdentificationTypes.IDN);
            var expected = HydraProtocolHelper.Build_ID_Packet();

            Assert.AreEqual(expected.ToString(), settings.IdentificationPacket.ToString());
        }

        [TestMethod]
        public void DeviceSettings_Constructor_TTI_MatchesBuildTtiIdPacket()
        {
            var settings = new DeviceSettings(DeviceSettings.IdentificationTypes.TTI);
            var expected = HydraProtocolHelper.Build_TTI_ID_Packet();

            Assert.AreEqual(expected.ToString(), settings.IdentificationPacket.ToString());
        }

        [TestMethod]
        public void DeviceSettings_Constructor_Modbus_MatchesOptidewDewpointPacket()
        {
            var settings = new DeviceSettings(DeviceSettings.IdentificationTypes.Modbus);
            var expected = HydraProtocolHelper.Build_OptidewGetDewpoint();

            Assert.AreEqual(expected.ToString(), settings.IdentificationPacket.ToString());
        }

        #endregion

        #region IdentificationTypes Enum

        [TestMethod]
        public void IdentificationTypes_IDN_Exists()
        {
            Assert.AreEqual(DeviceSettings.IdentificationTypes.IDN, (DeviceSettings.IdentificationTypes)0);
        }

        [TestMethod]
        public void IdentificationTypes_TTI_Exists()
        {
            Assert.AreEqual(DeviceSettings.IdentificationTypes.TTI, (DeviceSettings.IdentificationTypes)1);
        }

        [TestMethod]
        public void IdentificationTypes_Modbus_Exists()
        {
            Assert.AreEqual(DeviceSettings.IdentificationTypes.Modbus, (DeviceSettings.IdentificationTypes)2);
        }

        #endregion

        #region Clone Tests

        [TestMethod]
        public void Clone_ReturnsNewInstance()
        {
            var original = new DeviceSettings();

            var clone = original.Clone();

            Assert.IsNotNull(clone);
            Assert.AreNotSame(original, clone);
        }

        [TestMethod]
        public void Clone_CopiesIdentificationType()
        {
            var original = new DeviceSettings();

            var clone = original.Clone();

            Assert.AreEqual(original.IdentificationType, clone.IdentificationType);
        }

        [TestMethod]
        public void Clone_CopiesTimeoutValues()
        {
            var original = new DeviceSettings();

            var clone = original.Clone();

            Assert.AreEqual(original.SessionRequestTimeout_TimeSpan, clone.SessionRequestTimeout_TimeSpan);
            Assert.AreEqual(original.KeepAlive_RXTimeout_TimeSpan, clone.KeepAlive_RXTimeout_TimeSpan);
            Assert.AreEqual(original.ClocksDeviation_TimeSpan, clone.ClocksDeviation_TimeSpan);
            Assert.AreEqual(original.ClocksDeviation_MaxAttempts, clone.ClocksDeviation_MaxAttempts);
        }

        [TestMethod]
        public void Clone_CopiesSettingsName()
        {
            var original = new DeviceSettings();
            original.SettingsName = "TestDevice";

            var clone = original.Clone();

            Assert.AreEqual("TestDevice", clone.SettingsName);
        }

        #endregion

        #region Extended Coverage Tests

        [TestMethod]
        public void DeviceSettings_CanSetIdentificationType()
        {
            var settings = new DeviceSettings();
            settings.IdentificationType = DeviceSettings.IdentificationTypes.TTI;

            Assert.AreEqual(DeviceSettings.IdentificationTypes.TTI, settings.IdentificationType);
        }

        [TestMethod]
        public void DeviceSettings_CanSetModbusIdentificationType()
        {
            var settings = new DeviceSettings();
            settings.IdentificationType = DeviceSettings.IdentificationTypes.Modbus;

            Assert.AreEqual(DeviceSettings.IdentificationTypes.Modbus, settings.IdentificationType);
        }

        [TestMethod]
        public void DeviceSettings_SettingsName_DefaultIsNull()
        {
            var settings = new DeviceSettings();
            Assert.IsNull(settings.SettingsName);
        }

        [TestMethod]
        public void Clone_ReturnsDifferentReferenceWithSameDefaults()
        {
            var original = new DeviceSettings();
            var clone = original.Clone();

            // Verify the clone has the same default values
            Assert.AreEqual(original.IdentificationType, clone.IdentificationType);
            Assert.AreEqual(original.SessionRequestTimeout_TimeSpan, clone.SessionRequestTimeout_TimeSpan);
            Assert.AreEqual(original.ClocksDeviation_MaxAttempts, clone.ClocksDeviation_MaxAttempts);
        }

        #endregion
    }
}
