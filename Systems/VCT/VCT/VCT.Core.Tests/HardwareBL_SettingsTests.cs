using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Galcon.VCT.Core.Tests
{
    [TestClass]
    public class HardwareBL_SettingsTests
    {
        [TestCleanup]
        public void Cleanup()
        {
            HardwareBL_Settings._settings = null;
        }

        #region Constructor Tests

        [TestMethod]
        public void Constructor_InitializesAllDeviceTypes()
        {
            var settings = new HardwareBL_Settings();

            Assert.IsNotNull(settings.Hydra3type);
            Assert.IsNotNull(settings.Hydra2type);
            Assert.IsNotNull(settings.Agilent);
            Assert.IsNotNull(settings.Additel);
            Assert.IsNotNull(settings.Optidew);
            Assert.IsNotNull(settings.TTI22);
            Assert.IsNotNull(settings.Instek);
        }

        #endregion

        #region CreateDefaultSettings Tests

        [TestMethod]
        public void CreateDefaultSettings_ReturnsNonNull()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.IsNotNull(settings);
        }

        [TestMethod]
        public void CreateDefaultSettings_Hydra2type_Has20Channels()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(20, settings.Hydra2type.Channels.Count);
        }

        [TestMethod]
        public void CreateDefaultSettings_Hydra2type_MeasurementRateIsSlow()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(HardwareBL_DeviceType.MeasurementRates.SLOW, settings.Hydra2type.MeasurementRate);
        }

        [TestMethod]
        public void CreateDefaultSettings_Hydra3type_HasChannels101And102()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(2, settings.Hydra3type.Channels.Count);
            Assert.AreEqual(101, settings.Hydra3type.Channels[0]);
            Assert.AreEqual(102, settings.Hydra3type.Channels[1]);
        }

        [TestMethod]
        public void CreateDefaultSettings_Agilent_MaxChannelsIs1()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(1, settings.Agilent.MaxNumOfChannels);
        }

        [TestMethod]
        public void CreateDefaultSettings_Optidew_MeasureTypeIsDew()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(SensorType.MeasureTypes.Dew, settings.Optidew.Sensor.MeasureType);
        }

        [TestMethod]
        public void CreateDefaultSettings_TTI22_HasOneChannel()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(1, settings.TTI22.Channels.Count);
        }

        [TestMethod]
        public void CreateDefaultSettings_Instek_MaxChannelsIs50()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(50, settings.Instek.MaxNumOfChannels);
        }

        [TestMethod]
        public void CreateDefaultSettings_AllDeviceTypesHaveNonNullSensors()
        {
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            Assert.IsNotNull(settings.Hydra2type.Sensor);
            Assert.IsNotNull(settings.Hydra3type.Sensor);
            Assert.IsNotNull(settings.Agilent.Sensor);
            Assert.IsNotNull(settings.Additel.Sensor);
            Assert.IsNotNull(settings.Optidew.Sensor);
            Assert.IsNotNull(settings.TTI22.Sensor);
            Assert.IsNotNull(settings.Instek.Sensor);
        }

        #endregion

        #region Read (Cache) Tests

        [TestMethod]
        public void Read_WhenCachePopulated_ReturnsCachedInstance()
        {
            var cached = HardwareBL_Settings.CreateDefaultSettings();
            HardwareBL_Settings._settings = cached;

            var result = HardwareBL_Settings.Read();

            Assert.AreSame(cached, result);
        }

        #endregion

        #region Constants Tests

        [TestMethod]
        public void Constants_DefaultFileName_IsCorrect()
        {
            Assert.AreEqual("HydraBL_Settings.json", HardwareBL_Settings.DEFAULT_FILE_NAME);
        }

        [TestMethod]
        public void Constants_DefaultSettingsFolder_IsSettings()
        {
            Assert.AreEqual("Settings", HardwareBL_Settings.DEFAULT_SETTINGS_FOLDER);
        }

        #endregion
    }
}
