using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967 - alerts are identified the way LoggerData is. On the bench (2026-10-15, a Fluke 2625A
    /// as logger 21-337, sensor 21-675 on some channels and 31-98 on 14-16) the server sent
    /// <c>DeviceID:"FLUKE,2625A", LoggerID:"FLUKE,2625A"</c> on every alert while the readings went out
    /// as <c>DeviceID:"21-675", LoggerID:"21-337"</c>, so the app filed the alerts under a device it
    /// did not show and the operator saw nothing. Nothing either said the logger was back after the
    /// USB adapter was plugged in again.
    /// </summary>
    [TestClass]
    public class AlertIdentityTests
    {
        private const string Serial = "FLUKE,2625A";
        private const string Logger = "21-337";
        private static readonly DateTime SampleTime = new DateTime(2026, 10, 15, 9, 47, 22);

        private static readonly ChannelLabel SensorA = new ChannelLabel("21-675", Logger, "21-675", "Celsius", "2");
        private static readonly ChannelLabel SensorB = new ChannelLabel("31-98", Logger, "31-98", "Celsius", "2");
        private static readonly ChannelLabel NoAssociation = new ChannelLabel(null, null, null, null, null);

        private static Dictionary<int, ChannelLabel> BenchLabels()
        {
            return new Dictionary<int, ChannelLabel>
            {
                { 1, SensorA }, { 2, SensorA }, { 3, SensorA },
                { 14, SensorB }, { 15, SensorB }, { 16, SensorB },
            };
        }

        #region BuildAlertLine - the wire format

        [TestMethod]
        public void APerChannelAlertNamesTheSensorOnThatChannelAndTheLogger()
        {
            var line = ServerCore.BuildAlertLine(Serial, Logger, BenchLabels(), SensorB,
                "ChannelDisconnected", "Channel 14 disconnected - no sensor detected", SampleTime, "14");

            Assert.AreEqual(
                "CMD:\"Alert\", DeviceID:\"31-98\", LoggerID:\"21-337\", BatchID:\"31-98\", Channel:\"14\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Channel 14 disconnected - no sensor detected\", Time:\"10/15/2026 09:47:22\"",
                line);
        }

        [TestMethod]
        public void TwoSensorsOnOneLoggerEachChannelsAlertCarriesItsOwnSensor()
        {
            // The fallback is the LAST association (B); channel 1 is A's and must not be filed as B's.
            var one = ServerCore.BuildAlertLine(Serial, Logger, BenchLabels(), SensorB,
                "ChannelDisconnected", "Channel 1 disconnected - no sensor detected", SampleTime, "1");
            var fifteen = ServerCore.BuildAlertLine(Serial, Logger, BenchLabels(), SensorB,
                "DataRestored", "Channel 15 reconnected - readings resumed", SampleTime, "15");

            StringAssert.StartsWith(one, "CMD:\"Alert\", DeviceID:\"21-675\", LoggerID:\"21-337\", BatchID:\"21-675\", Channel:\"1\"");
            StringAssert.StartsWith(fifteen, "CMD:\"Alert\", DeviceID:\"31-98\", LoggerID:\"21-337\", BatchID:\"31-98\", Channel:\"15\"");
        }

        [TestMethod]
        public void APerChannelAlertCarriesTheIdsOfThatChannelsLoggerDataLine()
        {
            // The app pairs an alert with the readings by these ids; derive the expectation from
            // LoggerData itself rather than restating it, so the two cannot drift apart.
            var labels = BenchLabels();
            var fallback = new ChannelLabel("Z", Logger, "900", null, "2");
            var defaults = new ChannelLabel(Serial, Serial, "LIVE", "Celsius", "2");

            foreach (var channel in new[] { "1", "14", "7" })   // A, B, and an unlabelled channel
            {
                var data = ServerCore.BuildLoggerDataLines(new[] { channel, "20.5" }, labels, fallback, defaults, "10/15/2026 09:47:22").Single();
                var alert = ServerCore.BuildAlertLine(Serial, Logger, labels, fallback,
                    "ChannelDisconnected", "x", SampleTime, channel);

                foreach (var field in new[] { "DeviceID", "LoggerID", "BatchID" })
                {
                    Assert.AreEqual(Field(data, field), Field(alert, field), field + " for channel " + channel);
                }
            }
        }

        [TestMethod]
        public void ALoggerWideAlertCarriesTheLoggersMabaIdEverywhere()
        {
            var line = ServerCore.BuildAlertLine(Serial, Logger, BenchLabels(), SensorB,
                "ChannelDisconnected", "Logger {logger} disconnected - no data received", new DateTime(2026, 10, 15, 9, 51, 57), null);

            Assert.AreEqual(
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger 21-337 disconnected - no data received\", Time:\"10/15/2026 09:51:57\"",
                line);
        }

        [TestMethod]
        public void ALoggerWideRestoreCarriesTheSameKeyAsTheDisconnect()
        {
            // The app closes the ALL range only with a DataRestored on the same deviceId:ALL.
            var line = ServerCore.BuildAlertLine(Serial, Logger, BenchLabels(), SensorB,
                "DataRestored", "Logger {logger} reconnected", new DateTime(2026, 10, 15, 9, 53, 53), "ALL");

            Assert.AreEqual(
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Logger 21-337 reconnected\", Time:\"10/15/2026 09:53:53\"",
                line);
        }

        [TestMethod]
        public void AnUnconfiguredLoggerKeepsTheSerialAsBefore()
        {
            // No LoggerConfiguration and no SensorsAssociation ever received: today's line, unchanged.
            var wide = ServerCore.BuildAlertLine(Serial, null, new Dictionary<int, ChannelLabel>(), NoAssociation,
                "ChannelDisconnected", "Logger {logger} disconnected - no data received", SampleTime, null);
            var channel = ServerCore.BuildAlertLine(Serial, null, null, NoAssociation,
                "ChannelDisconnected", "Channel 14 disconnected - no sensor detected", SampleTime, "14");

            Assert.AreEqual(
                "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger FLUKE,2625A disconnected - no data received\", Time:\"10/15/2026 09:47:22\"",
                wide);
            Assert.AreEqual(
                "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\", Channel:\"14\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Channel 14 disconnected - no sensor detected\", Time:\"10/15/2026 09:47:22\"",
                channel);
        }

        [TestMethod]
        public void WithoutALoggerIdALoggerWideAlertKeepsTheClientsBatch()
        {
            // Several loggers that cannot be told apart: the pre-MBA-967 line, batch included.
            var line = ServerCore.BuildAlertLine(Serial, null, null, new ChannelLabel("A", "L", "B-7", null, null),
                "DataTimeout", "No data received for 60 seconds", SampleTime, null);

            StringAssert.StartsWith(line, "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"B-7\", Channel:\"ALL\"");
        }

        #endregion

        #region ResolveAlertLoggerId

        [TestMethod]
        public void NoLoggerIdNamedMeansNone()
        {
            Assert.IsNull(ServerCore.ResolveAlertLoggerId(new List<string>(), "Hydra2", id => "Hydra2"));
            Assert.IsNull(ServerCore.ResolveAlertLoggerId(null, "Hydra2", id => "Hydra2"));
        }

        [TestMethod]
        public void OneLoggerIdIsTheLogger()
        {
            Assert.AreEqual(Logger, ServerCore.ResolveAlertLoggerId(new List<string> { Logger }, null, null));
        }

        [TestMethod]
        public void SeveralLoggerIdsArePickedByTheDevicesFamily()
        {
            Func<string, string> familyOf = id => id == Logger ? "Hydra2" : "Agilent";

            Assert.AreEqual(Logger, ServerCore.ResolveAlertLoggerId(new List<string> { "21-900", Logger }, "Hydra2", familyOf));
        }

        [TestMethod]
        public void SeveralLoggerIdsThatCannotBeToldApartGiveNone()
        {
            // Naming a logger the alert may not be about is worse than the serial.
            Assert.IsNull(ServerCore.ResolveAlertLoggerId(new List<string> { "21-900", Logger }, "Hydra2", id => "Hydra2"));
            Assert.IsNull(ServerCore.ResolveAlertLoggerId(new List<string> { "21-900", Logger }, null, id => "Hydra2"));
        }

        #endregion

        private static string Field(string line, string name)
        {
            var m = Regex.Match(line, name + ":\"([^\"]+)\"");
            Assert.IsTrue(m.Success, name + " missing from " + line);
            return m.Groups[1].Value;
        }
    }

    /// <summary>
    /// MBA-967 - the same, end to end: a client configures logger 21-337 through the socket exactly as
    /// the app's Confirm does, and the alerts the server sends that client about the Fluke are read back
    /// off the client's link. Also the logger coming back: one DataRestored on ALL after a drop alert.
    /// </summary>
    [TestClass]
    public class AlertBroadcastTests
    {
        private const string Logger = "21-337";
        private static readonly Regex TimeField = new Regex("Time:\"[^\"]+\"");

        [TestInitialize]
        public void Setup()
        {
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
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

        private static MockComLayer ConfiguredClient(ServerCore server)
        {
            var com = new MockComLayer();
            var ws = new WebSocketDeviceHost(new EventsBus(), com, "WS");
            server.RegisterWebSocketClient("WS", ws);

            // The logger dialog's Confirm: the full list, then one association per sensor.
            com.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"" + Logger + "\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"1,2,14,15,16\", DeviceID:\"0\"");
            com.SimulateStringDataReceived(Association("21-675", "1,2"));
            com.SimulateStringDataReceived(Association("31-98", "14,15,16"));
            return com;
        }

        private static string Association(string sensor, string channels)
        {
            return "CMD:\"SensorsAssociation\", LoggerID:\"" + Logger + "\", DeviceID:\"" + sensor + "\", BatchID:\"" + sensor
                 + "\", BatchChannels:\"" + channels + "\", Units:\"Celsius\", Resolution:\"2\", SendData:\"true\"";
        }

        private static HardwareDeviceHost IdentifiedFluke(EventsBus bus, out MockComLayer com)
        {
            com = new MockComLayer();
            var host = new HardwareDeviceHost(bus, com, new DeviceSettings());
            host.InitSessions();
            var idn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idn, 0, idn.Length);
            Assert.AreEqual("FLUKE,2625A", host.SN, "test setup: the host never picked up the serial");
            return host;
        }

        private static List<string> Alerts(MockComLayer client)
        {
            return client.SentStrings.Where(s => s.StartsWith("CMD:\"Alert\"", StringComparison.Ordinal))
                                     .Select(s => TimeField.Replace(s, "Time:\"T\""))
                                     .ToList();
        }

        [TestMethod]
        public void ABLsChannelAlertReachesTheClientUnderThatChannelsSensor()
        {
            var server = new ServerCore();
            var client = ConfiguredClient(server);
            var fluke = IdentifiedFluke(server.MainEventsBus, out _);

            fluke.RaiseAlert("ChannelDisconnected", "Channel 14 disconnected - no sensor detected", "14");
            fluke.RaiseAlert("ChannelDisconnected", "Channel 1 disconnected - no sensor detected", "1");

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"31-98\", LoggerID:\"21-337\", BatchID:\"31-98\", Channel:\"14\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Channel 14 disconnected - no sensor detected\", Time:\"T\"",
                "CMD:\"Alert\", DeviceID:\"21-675\", LoggerID:\"21-337\", BatchID:\"21-675\", Channel:\"1\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Channel 1 disconnected - no sensor detected\", Time:\"T\"",
            }, Alerts(client));
        }

        [TestMethod]
        public void ADroppedLinkAndItsReturnAreAnnouncedOnceEachUnderTheLogger()
        {
            var server = new ServerCore();
            var client = ConfiguredClient(server);
            var fluke = IdentifiedFluke(server.MainEventsBus, out var link);

            // The USB adapter is unplugged: the link drops without anyone calling Disconnect().
            link.IsConnected = false;
            link.SimulateLayerClosed();

            // Plugged in again: ServerCore reuses the host for the known serial and re-inits it.
            var newLink = new MockComLayer();
            fluke.InitSessions(new HardwareDeviceHost(new EventsBus(), newLink, new DeviceSettings()));

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger 21-337 disconnected - no data received\", Time:\"T\"",
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Logger 21-337 reconnected\", Time:\"T\"",
            }, Alerts(client));
        }

        [TestMethod]
        public void TheReturnIsAnnouncedOnlyOncePerDrop()
        {
            var server = new ServerCore();
            var client = ConfiguredClient(server);
            var fluke = IdentifiedFluke(server.MainEventsBus, out var link);
            link.IsConnected = false;
            link.SimulateLayerClosed();
            fluke.InitSessions(new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings()));

            // Found again on another link with no drop in between, and a plain re-init.
            fluke.InitSessions(new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings()));
            fluke.BL = new MockDeviceBL();
            fluke.ReinitializeBL("test");

            Assert.AreEqual(1, Alerts(client).Count(a => a.Contains("AlertType:\"DataRestored\"")));
        }

        [TestMethod]
        public void TheFirstIdentificationAnnouncesNothing()
        {
            var server = new ServerCore();
            var client = ConfiguredClient(server);

            var fluke = IdentifiedFluke(server.MainEventsBus, out _);
            fluke.BL = new MockDeviceBL();
            fluke.ReinitializeBL("live reconfiguration");

            Assert.AreEqual(0, Alerts(client).Count);
        }

        [TestMethod]
        public void AnUnconfiguredClientStillGetsTheSerialAlerts()
        {
            var server = new ServerCore();
            var client = new MockComLayer();
            server.RegisterWebSocketClient("WS", new WebSocketDeviceHost(new EventsBus(), client, "WS"));
            var fluke = IdentifiedFluke(server.MainEventsBus, out var link);

            link.IsConnected = false;
            link.SimulateLayerClosed();
            fluke.InitSessions(new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings()));

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger FLUKE,2625A disconnected - no data received\", Time:\"T\"",
                "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\", Channel:\"ALL\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Logger FLUKE,2625A reconnected\", Time:\"T\"",
            }, Alerts(client));
        }

        [TestMethod]
        public void WithNoClientConnectedADropAndReturnDoNotThrow()
        {
            var server = new ServerCore();
            var fluke = IdentifiedFluke(server.MainEventsBus, out var link);

            link.IsConnected = false;
            link.SimulateLayerClosed();
            fluke.InitSessions(new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings()));
            fluke.RaiseAlert("ChannelDisconnected", "Channel 14 disconnected - no sensor detected", "14");

            Assert.IsFalse(fluke.DisconnectAlerted);
        }

        [TestMethod]
        public void AClientWhoseLinkIsDownIsSkipped()
        {
            var server = new ServerCore();
            var client = ConfiguredClient(server);
            client.IsConnected = false;
            var fluke = IdentifiedFluke(server.MainEventsBus, out _);

            fluke.RaiseAlert("ChannelDisconnected", "Channel 14 disconnected - no sensor detected", "14");

            Assert.AreEqual(0, Alerts(client).Count);
        }
    }
}
