using System;
using System.Collections.Generic;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967, "the first Confirm scans all channels". On the bench, 2026-09-30: the operator chose
    /// channels 1,3,5,6,7; the app sent LoggerConfiguration, SensorsAssociation and Status:Start
    /// together; no logger had been identified yet (that waits for the Start) and 21-337 was in no
    /// Masters list, so the list was dropped and the logger was set up from the settings file. Only a
    /// second Confirm, arriving while the logger was live, applied the operator's channels.
    /// </summary>
    [TestClass]
    public class HeldLoggerConfigTests
    {
        private const string Logger = "21-337";
        private HardwareBL_Settings _settings;

        [TestInitialize]
        public void Setup()
        {
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            _settings = HardwareBL_Settings._settings;
            _settings.Hydra2type.Channels = new List<int> { 1, 2, 3, 5, 11, 15 };   // the bench's settings file

            // Families are process-wide; other tests leave a live Hydra2 behind, and with one live
            // family the message would be routed at once - which is the second-Confirm case, not this one.
            foreach (var family in HardwareBL_Settings.ActiveFamilies())
            {
                HardwareBL_Settings.UnregisterActiveFamily(family);
            }
            HardwareBL_Settings.ClearPendingWebSocketConfig();
        }

        [TestCleanup]
        public void Cleanup()
        {
            HardwareBL_Settings.ClearPendingWebSocketConfig();
            HardwareBL_Settings._settings = null;
        }

        [TestMethod]
        public void AListBeforeTheLoggerIsIdentifiedIsHeldNotDropped()
        {
            Assert.IsNull(_settings.ApplyWebSocketConfig(Logger, "slow", "30", "01,03,05,06,07"));

            Assert.IsTrue(HardwareBL_Settings.IsWebSocketConfigHeld(Logger));
            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 5, 11, 15 }, _settings.Hydra2type.Channels,
                "nothing is applied until a logger is identified");
        }

        [TestMethod]
        public void TheHeldListIsAppliedWhenTheLoggerRegisters()
        {
            _settings.ApplyWebSocketConfig(Logger, "slow", "30", "01,03,05,06,07");

            var summary = _settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow);

            StringAssert.Contains(summary, "channels=[1,3,5,6,7]");
            CollectionAssert.AreEqual(new List<int> { 1, 3, 5, 6, 7 }, _settings.Hydra2type.Channels);
            Assert.IsFalse(HardwareBL_Settings.IsWebSocketConfigHeld(Logger), "applied once, then gone");
        }

        [TestMethod]
        public void ASensorsAssociationMergesIntoTheHeldConfiguration()
        {
            // SensorsAssociation carries channels only; the rate and interval from LoggerConfiguration stay.
            // MBA-967: its channels are added to the held list, not substituted for it - one
            // SensorsAssociation arrives per sensor, and substituting kept only the last sensor's.
            _settings.ApplyWebSocketConfig(Logger, "fast", "10", "01,03,05,06,07");
            _settings.AddWebSocketSensorChannels(Logger, "02,04");

            var summary = _settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow);

            StringAssert.Contains(summary, "channels=[1,2,3,4,5,6,7]");
            StringAssert.Contains(summary, "interval=10");
            StringAssert.Contains(summary, "rate=FAST");
        }

        [TestMethod]
        public void AnOldHeldListIsNotAppliedToALaterLogger()
        {
            var longAgo = DateTime.UtcNow - HardwareBL_Settings.PendingConfigLifetime - TimeSpan.FromMinutes(1);
            HardwareBL_Settings.HoldPendingWebSocketConfig(Logger, null, null, "01,03", longAgo);

            Assert.IsNull(_settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow));
            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 5, 11, 15 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void ARoutedMessageReplacesTheHeldOne()
        {
            _settings.ApplyWebSocketConfig(Logger, null, null, "01,03");
            _settings.ApplyWebSocketConfig("21-338", null, null, "02,04");

            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            try
            {
                Assert.IsNotNull(_settings.ApplyWebSocketConfig(Logger, null, null, "07,08"));
                Assert.IsFalse(HardwareBL_Settings.IsWebSocketConfigHeld(Logger),
                    "the older, held list must not be re-applied at the next init");
                Assert.IsTrue(HardwareBL_Settings.IsWebSocketConfigHeld("21-338"),
                    "another logger's held list is not this message's to drop");
            }
            finally
            {
                HardwareBL_Settings.UnregisterActiveFamily("Hydra2");
            }
        }

        [TestMethod]
        public void TwoLoggersConfiguredBeforeEitherIsIdentifiedConfigureNeither()
        {
            // The BL knows its logger's serial number, not its MABA id, so it cannot pick its own.
            // Applying the latest - the old behaviour - would set up logger A with B's channels.
            _settings.ApplyWebSocketConfig(Logger, "slow", "30", "01,03,05,06,07");
            _settings.ApplyWebSocketConfig("21-338", "fast", "10", "02,04");

            Assert.IsNull(_settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow, out var ambiguous));

            Assert.AreEqual("21-337,21-338", ambiguous);
            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 5, 11, 15 }, _settings.Hydra2type.Channels);
            Assert.IsFalse(HardwareBL_Settings.IsWebSocketConfigHeld(Logger), "dropped, so a later logger cannot take it either");
            Assert.IsFalse(HardwareBL_Settings.IsWebSocketConfigHeld("21-338"));
        }

        [TestMethod]
        public void EachLoggersMessagesMergeIntoItsOwnHeldConfiguration()
        {
            // A SensorsAssociation for B must not overwrite A's held channels.
            _settings.ApplyWebSocketConfig(Logger, "fast", "10", "01,03");
            _settings.ApplyWebSocketConfig("21-338", null, null, "02,04");

            Assert.IsTrue(HardwareBL_Settings.IsWebSocketConfigHeld(Logger));
            Assert.IsTrue(HardwareBL_Settings.IsWebSocketConfigHeld("21-338"));
        }

        [TestMethod]
        public void AnExpiredConfigurationDoesNotMakeTheLiveOneAmbiguous()
        {
            var longAgo = DateTime.UtcNow - HardwareBL_Settings.PendingConfigLifetime - TimeSpan.FromMinutes(1);
            HardwareBL_Settings.HoldPendingWebSocketConfig("21-338", null, null, "02,04", longAgo);
            _settings.ApplyWebSocketConfig(Logger, null, null, "01,03");

            var summary = _settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow, out var ambiguous);

            Assert.IsNull(ambiguous);
            StringAssert.Contains(summary, "channels=[1,3]");
        }

        [TestMethod]
        public void NothingHeldChangesNothing()
        {
            Assert.IsNull(_settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow));
        }

        [TestMethod]
        public void TheFirstInitScansTheOperatorsChannels()
        {
            // The whole sequence: the list arrives, then the logger is identified and its BL starts.
            _settings.ApplyWebSocketConfig(Logger, "slow", "30", "01,03,05,06,07");

            var blCore = new Hydra2BLCore();
            blCore.Start(new ServerCore());
            var com = new MockComLayer();
            var host = new HardwareDeviceHost(new EventsBus(), com, new DeviceSettings());
            var sn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(sn, 0, sn.Length);

            try
            {
                blCore.OnDeviceConnetion(host);   // OnCreateStates, before any InitChannels step

                CollectionAssert.AreEqual(new List<int> { 1, 3, 5, 6, 7 }, _settings.Hydra2type.Channels);
            }
            finally
            {
                HardwareBL_Settings.UnregisterActiveFamily("Hydra2");
            }
        }
    }
}
