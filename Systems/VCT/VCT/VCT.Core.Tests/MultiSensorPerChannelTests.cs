using System;
using System.Collections.Generic;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967, several sensors on one logger. On Confirm the app sends one LoggerConfiguration with
    /// every channel of the logger, then one SensorsAssociation per sensor naming only that sensor's
    /// channels. Before this, each SensorsAssociation replaced the logger's channel list (sensor A on
    /// 1-3 and B on 4-6 left only 4-6 scanned) and overwrote the one association the socket kept, so
    /// every reading was labelled as the last sensor's.
    /// </summary>
    [TestClass]
    public class MultiSensorPerChannelTests
    {
        private const string Logger = "21-337";
        private HardwareBL_Settings _settings;

        [TestInitialize]
        public void Setup()
        {
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            _settings = HardwareBL_Settings._settings;
            foreach (var family in HardwareBL_Settings.ActiveFamilies())
            {
                HardwareBL_Settings.UnregisterActiveFamily(family);
            }
            HardwareBL_Settings.ClearPendingWebSocketConfig();
        }

        [TestCleanup]
        public void Cleanup()
        {
            foreach (var family in HardwareBL_Settings.ActiveFamilies())
            {
                HardwareBL_Settings.UnregisterActiveFamily(family);
            }
            HardwareBL_Settings.ClearPendingWebSocketConfig();
            HardwareBL_Settings._settings = null;
        }

        #region channel list: LoggerConfiguration sets, SensorsAssociation adds

        [TestMethod]
        public void ASensorsChannelsAreAddedToTheLiveList()
        {
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            _settings.Hydra2type.Channels = new List<int> { 1, 2, 3 };

            var summary = _settings.AddWebSocketSensorChannels(Logger, "4,5,6");

            StringAssert.Contains(summary, "channels=[1,2,3,4,5,6]");
            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 4, 5, 6 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void TwoSensorsOnOneLoggerKeepBothChannelSets()
        {
            // The bench case: A on 1-3, B on 4-6. Replacing left 4-6.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            _settings.Hydra2type.Channels = new List<int> { 20 };

            _settings.AddWebSocketSensorChannels(Logger, "01,02,03");
            _settings.AddWebSocketSensorChannels(Logger, "04,05,06");

            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 4, 5, 6, 20 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void AFullConfirmLeavesTheLoggerConfigurationsChannels()
        {
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");

            Assert.IsNotNull(_settings.ApplyWebSocketConfig(Logger, "slow", "30", "1-6"));
            Assert.IsNull(_settings.AddWebSocketSensorChannels(Logger, "1-3"), "already present: no change, no re-init");
            Assert.IsNull(_settings.AddWebSocketSensorChannels(Logger, "4-6"), "already present: no change, no re-init");

            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 4, 5, 6 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void ALoggerConfigurationStillReplacesTheList()
        {
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            _settings.Hydra2type.Channels = new List<int> { 1, 2, 3, 4, 5, 6 };

            StringAssert.Contains(_settings.ApplyWebSocketConfig(Logger, null, null, "2,3"), "channels=[2,3]");

            CollectionAssert.AreEqual(new List<int> { 2, 3 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void ChannelsAlreadyPresentChangeNothingEvenInAnUnsortedList()
        {
            // A hand-written settings file need not be ascending; a no-op must not reorder it,
            // or it would report a change and re-initialize the logger for nothing.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            _settings.Hydra2type.Channels = new List<int> { 15, 1, 3 };

            Assert.IsNull(_settings.AddWebSocketSensorChannels(Logger, "1,3"));

            CollectionAssert.AreEqual(new List<int> { 15, 1, 3 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void HeldSensorChannelsAreAddedNotReplaced()
        {
            // Before the logger is identified, every message is held; the held list gets the same union.
            _settings.ApplyWebSocketConfig(Logger, "fast", "10", "07");
            _settings.AddWebSocketSensorChannels(Logger, "01,02,03");
            _settings.AddWebSocketSensorChannels(Logger, "04,05,06");

            var summary = _settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow);

            StringAssert.Contains(summary, "channels=[1,2,3,4,5,6,7]");
            StringAssert.Contains(summary, "rate=FAST");
            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 4, 5, 6, 7 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void AHeldLoggerConfigurationStillReplacesTheHeldList()
        {
            _settings.AddWebSocketSensorChannels(Logger, "01,02,03");
            _settings.ApplyWebSocketConfig(Logger, null, null, "07,08");

            var summary = _settings.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow);

            StringAssert.Contains(summary, "channels=[7,8]");
        }

        [TestMethod]
        public void ParseChannelsIsTheOneParserForBothUses()
        {
            CollectionAssert.AreEqual(new List<int> { 1, 3, 4, 5, 9 }, HardwareBL_Settings.ParseChannels("01,03, 4-5 9"));
        }

        #endregion

        #region per-channel labels on the WebSocket host

        private static (WebSocketDeviceHost host, MockComLayer com) NewHost()
        {
            var com = new MockComLayer();
            return (new WebSocketDeviceHost(new EventsBus(), com, "WS"), com);
        }

        private static string Association(string device, string batch, string channels, string units = "Celsius", string logger = Logger)
        {
            return "CMD:\"SensorsAssociation\", LoggerID:\"" + logger + "\", DeviceID:\"" + device + "\", BatchID:\"" + batch
                 + "\", BatchChannels:\"" + channels + "\", Units:\"" + units + "\", Resolution:\"3\", SendData:\"true\"";
        }

        private static string Configuration(string logger, string channels)
        {
            return "CMD:\"LoggerConfiguration\", LoggerID:\"" + logger + "\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"" + channels + "\", DeviceID:\"0\"";
        }

        [TestMethod]
        public void EachSensorLabelsItsOwnChannels()
        {
            var (host, com) = NewHost();

            com.SimulateStringDataReceived(Association("A", "100", "01,02,03"));
            com.SimulateStringDataReceived(Association("B", "200", "04,05,06", "Fahrenheit"));

            var labels = host.ChannelLabels;
            Assert.AreEqual(6, labels.Count);
            Assert.AreEqual("A", labels[1].DeviceId);
            Assert.AreEqual("100", labels[3].BatchId);
            Assert.AreEqual("Celsius", labels[3].Units);
            Assert.AreEqual("B", labels[4].DeviceId);
            Assert.AreEqual("200", labels[6].BatchId);
            Assert.AreEqual("Fahrenheit", labels[6].Units);
            Assert.AreEqual("3", labels[6].Resolution);
            Assert.AreEqual(Logger, labels[6].LoggerId);
            Assert.AreEqual("B", host.AssociatedDeviceId, "the last association stays the fallback");
        }

        [TestMethod]
        public void TwoSensorsThroughTheSocketLeaveTheLoggerScanningBoth()
        {
            // End to end through handlePacket: the bench case, A on 1-3 then B on 4-6.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            _settings.Hydra2type.Channels = new List<int> { 20 };
            var (_, com) = NewHost();

            com.SimulateStringDataReceived(Association("A", "100", "01,02,03"));
            com.SimulateStringDataReceived(Association("B", "200", "04,05,06"));

            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 4, 5, 6, 20 }, _settings.Hydra2type.Channels);
        }

        [TestMethod]
        public void AnAssociationWithoutChannelsLabelsNothing()
        {
            var (host, com) = NewHost();

            com.SimulateStringDataReceived("CMD:\"SensorsAssociation\", LoggerID:\"" + Logger + "\", DeviceID:\"A\", BatchID:\"1\", Units:\"Celsius\"");

            Assert.AreEqual(0, host.ChannelLabels.Count);
            Assert.AreEqual("A", host.AssociatedDeviceId);
        }

        [TestMethod]
        public void ALoggerConfigurationClearsThatLoggersLabels()
        {
            var (host, com) = NewHost();
            com.SimulateStringDataReceived(Association("A", "100", "01,02,03"));
            com.SimulateStringDataReceived(Association("B", "200", "04,05,06"));

            // The configuration names channel 20 only: the labels go because they are this logger's.
            com.SimulateStringDataReceived(Configuration(Logger, "20"));

            Assert.AreEqual(0, host.ChannelLabels.Count);
        }

        [TestMethod]
        public void ALoggerConfigurationClearsTheLabelsOfTheChannelsItLists()
        {
            var (host, com) = NewHost();
            com.SimulateStringDataReceived(Association("A", "100", "01,02,03", logger: "21-900"));

            com.SimulateStringDataReceived(Configuration(Logger, "02"));

            CollectionAssert.AreEquivalent(new[] { 1, 3 }, new List<int>(host.ChannelLabels.Keys));
        }

        [TestMethod]
        public void AnotherLoggersConfigurationLeavesTheLabels()
        {
            var (host, com) = NewHost();
            com.SimulateStringDataReceived(Association("A", "100", "01,02,03"));

            com.SimulateStringDataReceived(Configuration("21-338", "09"));

            Assert.AreEqual(3, host.ChannelLabels.Count);
        }

        [TestMethod]
        public void ANewConfirmRelabels()
        {
            var (host, com) = NewHost();
            com.SimulateStringDataReceived(Configuration(Logger, "1-6"));
            com.SimulateStringDataReceived(Association("A", "100", "01,02,03"));
            com.SimulateStringDataReceived(Association("B", "200", "04,05,06"));

            // Second Confirm: B removed, A now on every channel.
            com.SimulateStringDataReceived(Configuration(Logger, "1-6"));
            com.SimulateStringDataReceived(Association("A", "100", "01,02,03,04,05,06"));

            Assert.AreEqual(6, host.ChannelLabels.Count);
            Assert.AreEqual("A", host.ChannelLabels[5].DeviceId);
        }

        [TestMethod]
        public void AReadersSnapshotIsNotChangedByALaterMessage()
        {
            // The broadcast path reads the labels while the WS thread may be writing them.
            var (host, com) = NewHost();
            com.SimulateStringDataReceived(Association("A", "100", "01"));
            var snapshot = host.ChannelLabels;

            com.SimulateStringDataReceived(Association("B", "200", "01,02"));
            com.SimulateStringDataReceived(Configuration(Logger, "1-6"));

            Assert.AreEqual(1, snapshot.Count);
            Assert.AreEqual("A", snapshot[1].DeviceId);
        }

        #endregion

        #region LoggerData lines grouped by label

        private const string Time = "10/05/2026 12:00:00";
        private static readonly ChannelLabel Defaults = new ChannelLabel("FLUKE,2625A", "FLUKE,2625A", "LIVE", "Celsius", "2");
        private static readonly ChannelLabel NoAssociation = new ChannelLabel(null, null, null, null, null);

        [TestMethod]
        public void NoLabelsGiveExactlyTheSingleLineOfBefore()
        {
            var fallback = new ChannelLabel("D", "L", "B", "Kelvin", "4");
            var parts = new[] { "1", "25.5", "2", "30" };

            var lines = ServerCore.BuildLoggerDataLines(parts, new Dictionary<int, ChannelLabel>(), fallback, Defaults, Time);

            Assert.AreEqual(1, lines.Count);
            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"D\", LoggerID:\"L\", BatchID:\"B\", Time:\"10/05/2026 12:00:00\", Units:\"Kelvin\", Resolution:\"4\", Channel:\"1\", Value:\"25.5\", Channel:\"2\", Value:\"30\"",
                lines[0]);
        }

        [TestMethod]
        public void NoAssociationAtAllUsesTheDevicesDefaults()
        {
            var lines = ServerCore.BuildLoggerDataLines(new[] { "1", "25.5" }, null, NoAssociation, Defaults, Time);

            Assert.AreEqual(1, lines.Count);
            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\", Time:\"10/05/2026 12:00:00\", Units:\"Celsius\", Resolution:\"2\", Channel:\"1\", Value:\"25.5\"",
                lines[0]);
        }

        [TestMethod]
        public void TwoSensorsGiveTwoLinesEachWithItsOwnChannels()
        {
            var a = new ChannelLabel("A", Logger, "100", "Celsius", "2");
            var b = new ChannelLabel("B", Logger, "200", "Fahrenheit", "3");
            var labels = new Dictionary<int, ChannelLabel> { { 1, a }, { 2, a }, { 3, a }, { 4, b }, { 5, b }, { 6, b } };
            var parts = new[] { "1", "20.1", "4", "30.4", "2", "20.2", "5", "30.5", "3", "20.3", "6", "30.6" };

            var lines = ServerCore.BuildLoggerDataLines(parts, labels, b, Defaults, Time);

            Assert.AreEqual(2, lines.Count);
            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"A\", LoggerID:\"21-337\", BatchID:\"100\", Time:\"10/05/2026 12:00:00\", Units:\"Celsius\", Resolution:\"2\", Channel:\"1\", Value:\"20.1\", Channel:\"2\", Value:\"20.2\", Channel:\"3\", Value:\"20.3\"",
                lines[0]);
            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"B\", LoggerID:\"21-337\", BatchID:\"200\", Time:\"10/05/2026 12:00:00\", Units:\"Fahrenheit\", Resolution:\"3\", Channel:\"4\", Value:\"30.4\", Channel:\"5\", Value:\"30.5\", Channel:\"6\", Value:\"30.6\"",
                lines[1]);
        }

        [TestMethod]
        public void UnlabelledChannelsGoTogetherUnderTheFallback()
        {
            var a = new ChannelLabel("A", Logger, "100", "Celsius", "2");
            var labels = new Dictionary<int, ChannelLabel> { { 1, a } };
            var fallback = new ChannelLabel("Z", Logger, "900", null, "2");
            var parts = new[] { "7", "1.0", "1", "2.0", "8", "3.0" };

            var lines = ServerCore.BuildLoggerDataLines(parts, labels, fallback, Defaults, Time);

            Assert.AreEqual(2, lines.Count);
            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"Z\", LoggerID:\"21-337\", BatchID:\"900\", Time:\"10/05/2026 12:00:00\", Units:\"Celsius\", Resolution:\"2\", Channel:\"7\", Value:\"1.0\", Channel:\"8\", Value:\"3.0\"",
                lines[0], "first-seen group first; empty Units takes the device default");
            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"A\", LoggerID:\"21-337\", BatchID:\"100\", Time:\"10/05/2026 12:00:00\", Units:\"Celsius\", Resolution:\"2\", Channel:\"1\", Value:\"2.0\"",
                lines[1]);
        }

        [TestMethod]
        public void ALabelEqualToTheFallbackSharesItsLine()
        {
            // One sensor on every channel: the labels and the last association agree - one line, as before.
            var a = new ChannelLabel("A", Logger, "100", "Celsius", "2");
            var labels = new Dictionary<int, ChannelLabel> { { 1, a } };

            var lines = ServerCore.BuildLoggerDataLines(new[] { "1", "1.0", "2", "2.0" }, labels, a, Defaults, Time);

            Assert.AreEqual(1, lines.Count);
            StringAssert.EndsWith(lines[0], "Channel:\"1\", Value:\"1.0\", Channel:\"2\", Value:\"2.0\"");
        }

        [TestMethod]
        public void ALabelsEmptyFieldsTakeTheDevicesDefaults()
        {
            var labels = new Dictionary<int, ChannelLabel> { { 1, new ChannelLabel("A", null, "", null, null) } };

            var lines = ServerCore.BuildLoggerDataLines(new[] { "1", "1.0" }, labels, NoAssociation, Defaults, Time);

            Assert.AreEqual(
                "CMD:\"LoggerData\", DeviceID:\"A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\", Time:\"10/05/2026 12:00:00\", Units:\"Celsius\", Resolution:\"2\", Channel:\"1\", Value:\"1.0\"",
                lines[0]);
        }

        [TestMethod]
        public void AChannelThatIsNotANumberIsUnlabelled()
        {
            var a = new ChannelLabel("A", Logger, "100", "Celsius", "2");
            var labels = new Dictionary<int, ChannelLabel> { { 1, a } };

            var lines = ServerCore.BuildLoggerDataLines(new[] { "x", "1.0" }, labels, NoAssociation, Defaults, Time);

            StringAssert.StartsWith(lines[0], "CMD:\"LoggerData\", DeviceID:\"FLUKE,2625A\"");
        }

        [TestMethod]
        public void ChannelLabelsAreEqualByValue()
        {
            var a = new ChannelLabel("A", "L", "B", "U", "R");
            var same = new ChannelLabel("A", "L", "B", "U", "R");

            Assert.IsTrue(a.Equals(same));
            Assert.AreEqual(a.GetHashCode(), same.GetHashCode());
            Assert.IsFalse(a.Equals(new ChannelLabel("A", "L", "B", "U", "other")));
            Assert.IsFalse(a.Equals((object)null));
            Assert.AreEqual(NoAssociation, new ChannelLabel(null, null, null, null, null));
            Assert.AreEqual(NoAssociation.GetHashCode(), new ChannelLabel(null, null, null, null, null).GetHashCode());
        }

        #endregion
    }
}
