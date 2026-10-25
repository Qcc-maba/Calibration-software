using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967, review of #30 - what the app has been told about a channel survives a re-init, and the
    /// logger's MABA id survives a browser reconnect. Driven end to end: the real Hydra2 BL on a Fluke
    /// identified on the server's bus, a client configured through the socket exactly as the app's
    /// Confirm does (logger 21-337, sensor 21-675 on 1-2, 31-98 on 14-16), and the alert lines read back
    /// off the client's link.
    /// <para>
    /// Before: every re-init (each Confirm, each USB reconnect, each power-cycle recovery) forgot the
    /// channels reported down. A sensor plugged back in meanwhile never announced its return, so the
    /// app kept it down for good; one still out was announced down again after every reconnect.
    /// </para>
    /// </summary>
    [TestClass]
    public class ChannelDownAcrossReinitTests
    {
        private const string Logger = "21-337";
        private const double Open = Hydra2DeviceBL.DISCONNECTED_CHANNEL_READING;
        private static readonly Regex TimeField = new Regex("Time:\"[^\"]+\"");

        private const string Ch14Down =
            "CMD:\"Alert\", DeviceID:\"31-98\", LoggerID:\"21-337\", BatchID:\"31-98\", Channel:\"14\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Channel 14 disconnected - no sensor detected\", Time:\"T\"";
        private const string Ch14Back =
            "CMD:\"Alert\", DeviceID:\"31-98\", LoggerID:\"21-337\", BatchID:\"31-98\", Channel:\"14\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Channel 14 reconnected - readings resumed\", Time:\"T\"";

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

        #region Fixture

        private sealed class Bench
        {
            public ServerCore Server;
            public HardwareDeviceHost Fluke;
            public MockComLayer Link;
            public MockComLayer Client;
            public PrivateObject BL;
        }

        /// <summary>The Fluke identified and driven by its Hydra2 BL, then the operator's Confirm.</summary>
        private static Bench ConfirmedBench()
        {
            var b = new Bench { Server = new ServerCore() };

            b.Link = new MockComLayer();
            b.Fluke = new HardwareDeviceHost(b.Server.MainEventsBus, b.Link, new DeviceSettings());
            b.Fluke.InitSessions();
            var idn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            b.Link.SimulateDataReceived(idn, 0, idn.Length);

            var blCore = new Hydra2BLCore();
            blCore.Start(b.Server);
            Assert.IsTrue(blCore.OnDeviceConnetion(b.Fluke), "test setup: the Hydra2 BL did not claim the Fluke");
            b.BL = new PrivateObject(b.Fluke.BL);

            b.Client = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS", new WebSocketDeviceHost(new EventsBus(), b.Client, "WS"));
            Confirm(b.Client, "1,2,14,15,16", ("21-675", "1,2"), ("31-98", "14,15,16"));
            CollectionAssert.AreEqual(new[] { 1, 2, 14, 15, 16 }, HardwareBL_Settings.Read().Hydra2type.Channels.ToArray(),
                "test setup: the Confirm did not reach the scan list");
            return b;
        }

        /// <summary>The logger dialog's Confirm: the full list, then one association per sensor.</summary>
        private static void Confirm(MockComLayer client, string channels, params (string Sensor, string Channels)[] sensors)
        {
            client.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"" + Logger + "\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"" + channels + "\", DeviceID:\"0\"");
            foreach (var s in sensors)
            {
                client.SimulateStringDataReceived("CMD:\"SensorsAssociation\", LoggerID:\"" + Logger + "\", DeviceID:\"" + s.Sensor + "\", BatchID:\"" + s.Sensor
                    + "\", BatchChannels:\"" + s.Channels + "\", Units:\"Celsius\", Resolution:\"2\", SendData:\"true\"");
            }
        }

        /// <summary>One logged scan, a value per scanned channel in the scan list's order.</summary>
        private static void Scan(Bench b, params double[] values)
        {
            var entry = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            entry.Measurements.AddRange(values);
            b.BL.Invoke("BroadcastEntry", entry);
        }

        private static List<string> Alerts(MockComLayer client)
        {
            return client.SentStrings.Where(s => s.StartsWith("CMD:\"Alert\"", StringComparison.Ordinal))
                                     .Select(s => TimeField.Replace(s, "Time:\"T\""))
                                     .ToList();
        }

        private static void Unplug(Bench b)
        {
            b.Link.IsConnected = false;
            b.Link.SimulateLayerClosed();
        }

        /// <summary>The adapter plugged in again: ServerCore hands the known serial's host the new link.</summary>
        private static void PlugBackIn(Bench b)
        {
            b.Link = new MockComLayer();
            b.Fluke.InitSessions(new HardwareDeviceHost(new EventsBus(), b.Link, new DeviceSettings()));
        }

        #endregion

        #region Finding 1 - the channels reported down survive a re-init

        [TestMethod]
        public void ASensorBackByTheNextConfirmIsAnnouncedOnceUnderItsOwnIds()
        {
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            // The operator plugs the sensor back in and confirms again: the Confirm re-inits the logger.
            Confirm(b.Client, "1,2,14,15,16", ("21-675", "1,2"), ("31-98", "14,15,16"));
            b.Fluke.ReinitializeBL("LoggerConfiguration change from web app");
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);

            CollectionAssert.AreEqual(new[] { Ch14Down, Ch14Back }, Alerts(b.Client));
        }

        [TestMethod]
        public void ASensorStillOutAfterAConfirmIsNotAnnouncedAgain()
        {
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            Confirm(b.Client, "1,2,14,15,16", ("21-675", "1,2"), ("31-98", "14,15,16"));
            b.Fluke.ReinitializeBL("LoggerConfiguration change from web app");
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);
            b.Fluke.ReinitializeBL("power-cycle recovery");
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            CollectionAssert.AreEqual(new[] { Ch14Down }, Alerts(b.Client));

            // ...and when it does come back, that is announced.
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);
            CollectionAssert.AreEqual(new[] { Ch14Down, Ch14Back }, Alerts(b.Client));
        }

        [TestMethod]
        public void AChannelTheConfirmTookOutIsClosedUnderTheIdsItWentDownWith()
        {
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            // Sensor 31-98 removed in the dialog: channel 14 is never scanned again, and its label is
            // gone with the Confirm - the client's last association is now 21-675.
            Confirm(b.Client, "1,2", ("21-675", "1,2"));
            b.Fluke.ReinitializeBL("LoggerConfiguration change from web app");

            CollectionAssert.AreEqual(new[]
            {
                Ch14Down,
                "CMD:\"Alert\", DeviceID:\"31-98\", LoggerID:\"21-337\", BatchID:\"31-98\", Channel:\"14\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Channel 14 removed from the scan - no longer monitored\", Time:\"T\"",
            }, Alerts(b.Client));
        }

        [TestMethod]
        public void AChannelTheConfirmTookOutIsForgotten_SoItsNextDisconnectIsAnnounced()
        {
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);
            Confirm(b.Client, "1,2", ("21-675", "1,2"));
            b.Fluke.ReinitializeBL("LoggerConfiguration change from web app");
            Scan(b, 20.1, 20.2);

            // Put back on the scan, still without a sensor: a new disconnect, announced again.
            Confirm(b.Client, "1,2,14,15,16", ("21-675", "1,2"), ("31-98", "14,15,16"));
            b.Fluke.ReinitializeBL("LoggerConfiguration change from web app");
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            var alerts = Alerts(b.Client);
            Assert.AreEqual(3, alerts.Count, string.Join("\n", alerts));
            Assert.AreEqual(Ch14Down, alerts[2]);
        }

        [TestMethod]
        public void AUsbReplugKeepsTheChannelsReportedDown()
        {
            var b = ConfirmedBench();
            var bl = b.Fluke.BL;
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            Unplug(b);
            PlugBackIn(b);
            Assert.AreSame(bl, b.Fluke.BL, "the reconnect reaches the same BL");

            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);   // still out: nothing more about channel 14
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);   // back

            CollectionAssert.AreEqual(new[]
            {
                Ch14Down,
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger 21-337 disconnected - no data received\", Time:\"T\"",
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Logger 21-337 reconnected\", Time:\"T\"",
                Ch14Back,
            }, Alerts(b.Client));
        }

        [TestMethod]
        public void ARestoreToAClientThatNeverHeardOfTheDisconnectUsesItsOwnLabels()
        {
            // The remembered ids are per connection: a browser that connected after the disconnect has
            // no range to close, and its restore is labelled like its LoggerData.
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, Open, 20.4, 20.5);

            var late = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS2", new WebSocketDeviceHost(new EventsBus(), late, "WS2"));
            Confirm(late, "1,2,14,15,16", ("21-675", "1,2,14"), ("31-98", "15,16"));
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"21-675\", LoggerID:\"21-337\", BatchID:\"21-675\", Channel:\"14\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Channel 14 reconnected - readings resumed\", Time:\"T\"",
            }, Alerts(late));
        }

        #endregion

        #region Finding 2 - the logger's MABA id survives a browser reconnect

        [TestMethod]
        public void ABrowserThatReconnectedIsToldAboutTheLoggerByItsMabaId()
        {
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);   // readings to the configured browser

            // The browser reloads: the old socket is dead, the new one has not re-sent its setup.
            b.Client.IsConnected = false;
            var fresh = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS2", new WebSocketDeviceHost(new EventsBus(), fresh, "WS2"));

            Unplug(b);
            PlugBackIn(b);

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger 21-337 disconnected - no data received\", Time:\"T\"",
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Logger 21-337 reconnected\", Time:\"T\"",
            }, Alerts(fresh));
        }

        [TestMethod]
        public void ADropAnnouncedToOneBrowserIsClosedUnderTheSameIdForTheNextOne()
        {
            var b = ConfirmedBench();
            Unplug(b);   // announced to the configured browser as 21-337

            b.Client.IsConnected = false;
            var fresh = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS2", new WebSocketDeviceHost(new EventsBus(), fresh, "WS2"));
            PlugBackIn(b);

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"21-337\", LoggerID:\"21-337\", BatchID:\"21-337\", Channel:\"ALL\", Value:\"0\", AlertType:\"DataRestored\", Message:\"Logger 21-337 reconnected\", Time:\"T\"",
            }, Alerts(fresh));
        }

        [TestMethod]
        public void AClientsOwnNamingWinsOverTheRememberedId()
        {
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);   // the device learns 21-337

            var other = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS2", new WebSocketDeviceHost(new EventsBus(), other, "WS2"));
            other.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"21-400\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"1,2,14,15,16\", DeviceID:\"0\"");

            Unplug(b);

            CollectionAssert.AreEqual(new[]
            {
                "CMD:\"Alert\", DeviceID:\"21-400\", LoggerID:\"21-400\", BatchID:\"21-400\", Channel:\"ALL\", Value:\"0\", AlertType:\"ChannelDisconnected\", Message:\"Logger 21-400 disconnected - no data received\", Time:\"T\"",
            }, Alerts(other));
        }

        [TestMethod]
        public void AClientNamingSeveralLoggersItCannotTellApartStillGetsTheSerial()
        {
            // The remembered id came from another connection; this one may have meant the other logger.
            var b = ConfirmedBench();
            Scan(b, 20.1, 20.2, 20.3, 20.4, 20.5);

            var other = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS2", new WebSocketDeviceHost(new EventsBus(), other, "WS2"));
            other.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"21-400\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"1,2\", DeviceID:\"0\"");
            other.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"21-500\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"1,2\", DeviceID:\"0\"");

            Unplug(b);

            var alert = Alerts(other).Single();
            StringAssert.StartsWith(alert, "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\"");
        }

        [TestMethod]
        public void ADeviceNoClientEverNamedKeepsTheSerial()
        {
            var b = ConfirmedBench();
            b.Client.IsConnected = false;   // configured, but nothing was ever sent to it
            var fresh = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS2", new WebSocketDeviceHost(new EventsBus(), fresh, "WS2"));

            Unplug(b);

            StringAssert.StartsWith(Alerts(fresh).Single(), "CMD:\"Alert\", DeviceID:\"FLUKE,2625A\", LoggerID:\"FLUKE,2625A\", BatchID:\"LIVE\"");
        }

        #endregion
    }
}
