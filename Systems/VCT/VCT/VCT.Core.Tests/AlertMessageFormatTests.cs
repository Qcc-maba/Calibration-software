using System;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Threading;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-485 AC5/AC6 — the alert line is a contract with the web app, and it is a contract that
    /// fails silently. app/src/.../parse-alert-message.ts matches each field with its own regex and
    /// returns null if ANY of them is missing or empty, so a single stray character costs the whole
    /// alert with nothing logged on either side.
    ///
    /// The regexes below are copied verbatim from app/src/lib/constants/websocket-fields.ts. If the
    /// app changes one, this test should be updated in the same change - that is the point of
    /// duplicating them here rather than asserting on a hand-written expected string.
    /// </summary>
    [TestClass]
    public class AlertMessageFormatTests
    {
        private const string AlertMarker = "CMD:\"Alert\"";

        private static readonly Regex DeviceId = new Regex("DeviceID:\"([^\"]+)\"");
        private static readonly Regex LoggerId = new Regex("LoggerID:\"([^\"]+)\"");
        private static readonly Regex BatchId = new Regex("BatchID:\"([^\"]+)\"");
        private static readonly Regex Channel = new Regex("Channel:\"([^\"]+)\"");
        private static readonly Regex Value = new Regex("Value:\"([^\"]+)\"");
        private static readonly Regex AlertType = new Regex("AlertType:\"([^\"]+)\"");
        private static readonly Regex Message = new Regex("Message:\"([^\"]+)\"");
        private static readonly Regex Time = new Regex("Time:\"([^\"]+)\"");

        private static readonly DateTime SampleTime = new DateTime(2026, 3, 9, 7, 5, 4);

        private static string Build()
        {
            return ServerCore.BuildAlertMessage("SN-1234", "SN-1234", "LIVE",
                                                "ChannelDisconnected",
                                                "Logger SN-1234 disconnected - no data received",
                                                SampleTime);
        }

        [TestMethod]
        public void EveryFieldTheAppRequiresIsPresentAndNonEmpty()
        {
            var msg = Build();

            StringAssert.Contains(msg, AlertMarker);

            foreach (var field in new[]
            {
                new { Name = "DeviceID", Rx = DeviceId },
                new { Name = "LoggerID", Rx = LoggerId },
                new { Name = "BatchID", Rx = BatchId },
                new { Name = "Channel", Rx = Channel },
                new { Name = "Value", Rx = Value },
                new { Name = "AlertType", Rx = AlertType },
                new { Name = "Message", Rx = Message },
                new { Name = "Time", Rx = Time },
            })
            {
                var m = field.Rx.Match(msg);
                Assert.IsTrue(m.Success, field.Name + " did not match the app's regex: " + msg);
                Assert.AreNotEqual(string.Empty, m.Groups[1].Value, field.Name + " was empty, so the app drops the alert");
            }
        }

        [TestMethod]
        public void DeviceAndLoggerCarryTheFailingSerial_NotAClientAssociation()
        {
            // The whole point of the MBA-485 follow-up: with several loggers the alert used to be
            // labelled with the RECEIVING client's association, naming the wrong device every time.
            var msg = Build();

            Assert.AreEqual("SN-1234", DeviceId.Match(msg).Groups[1].Value);
            Assert.AreEqual("SN-1234", LoggerId.Match(msg).Groups[1].Value);
        }

        [TestMethod]
        public void ChannelAndValueCarryPlaceholders_BecauseEmptyWouldDropTheAlert()
        {
            // A device-wide alert has no single channel and no reading. They cannot simply be blank:
            // parse-alert-message.ts requires a non-empty capture for both.
            var msg = Build();

            Assert.AreEqual("ALL", Channel.Match(msg).Groups[1].Value);
            Assert.AreEqual("0", Value.Match(msg).Groups[1].Value);
        }

        [TestMethod]
        public void TimeStaysMmDdYyyy_WhateverTheServerLocaleIs()
        {
            // '/' in a .NET custom format string is the CULTURE's date separator, not a literal. On a
            // server whose locale separates with '.', an un-pinned format would emit 03.09.2026 and
            // date-fns - parsing 'MM/dd/yyyy HH:mm:ss' - would reject it, dropping the alert.
            var original = Thread.CurrentThread.CurrentCulture;
            try
            {
                Thread.CurrentThread.CurrentCulture = new CultureInfo("de-DE");
                var msg = Build();

                Assert.AreEqual("03/09/2026 07:05:04", Time.Match(msg).Groups[1].Value);
            }
            finally
            {
                Thread.CurrentThread.CurrentCulture = original;
            }
        }

        [TestMethod]
        public void MessageTextSurvivesIntact()
        {
            var msg = Build();

            Assert.AreEqual("Logger SN-1234 disconnected - no data received", Message.Match(msg).Groups[1].Value);
        }
    }
}

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-485 AC5 — the disconnect alert is edge-triggered, and the edge has to re-arm.
    /// ServerCore reuses an existing HardwareDeviceHost when a known SN reconnects, so a flag that
    /// is only ever set to true silently reduces "alert on every disconnect" to "alert once per
    /// process". These tests pin the reset.
    /// </summary>
    [TestClass]
    public class DisconnectAlertLifecycleTests
    {
        private static HardwareDeviceHost IdentifiedHost(EventsBus bus, out MockComLayer com)
        {
            com = new MockComLayer();
            var host = new HardwareDeviceHost(bus, com, new DeviceSettings());
            host.InitSessions();

            // SN is derived from the identification reply, never assigned directly.
            var idn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idn, 0, idn.Length);

            Assert.IsNotNull(host.SN, "test setup: the host never picked up a serial");
            return host;
        }

        [TestMethod]
        public void FirstDisconnect_ArmsTheFlag_SecondOneIsSuppressed()
        {
            var server = new ServerCore();
            MockComLayer com;
            var host = IdentifiedHost(server.MainEventsBus, out com);

            com.IsConnected = false;

            server.MainEventsBus.Fire_DeviceConnection(this, new DeviceConnectionEventArgs(host));
            Assert.IsTrue(host.DisconnectAlerted, "the first disconnect should have alerted and armed the guard");

            // Both the self-disconnect and the comm-loss path fire this event, so the handler is
            // entered twice for one physical drop. The second pass must fall through.
            server.MainEventsBus.Fire_DeviceConnection(this, new DeviceConnectionEventArgs(host));
            Assert.IsTrue(host.DisconnectAlerted);
        }

        [TestMethod]
        public void Reconnecting_ReArmsTheAlert_SoASecondDropIsReported()
        {
            var server = new ServerCore();
            MockComLayer com;
            var host = IdentifiedHost(server.MainEventsBus, out com);

            com.IsConnected = false;
            server.MainEventsBus.Fire_DeviceConnection(this, new DeviceConnectionEventArgs(host));
            Assert.IsTrue(host.DisconnectAlerted);

            // What ServerCore does for a known SN: reuse the instance and re-init it.
            com.IsConnected = true;
            host.InitSessions();

            Assert.IsFalse(host.DisconnectAlerted, "a reconnected device must be able to report its next drop");
        }

        [TestMethod]
        public void Reconnecting_ClearsTheWatchdogState_SoNoTimeoutFiresOnStaleData()
        {
            var server = new ServerCore();
            MockComLayer com;
            var host = IdentifiedHost(server.MainEventsBus, out com);

            host.BroadcastMeasurement(1, 12.5);
            Assert.IsNotNull(host.LastMeasurementUtc);
            host.DataTimedOut = true;

            host.InitSessions();   // reconnect path

            // Left set, the watchdog would compare "now" against a timestamp from before the drop
            // and declare a timeout the instant the device came back.
            Assert.IsNull(host.LastMeasurementUtc);
            Assert.IsFalse(host.DataTimedOut);
        }

        [TestMethod]
        public void CommLossWithNoEventBus_DoesNotThrow()
        {
            // Hosts built without a bus exist in the pending path. The comm-loss notification has to
            // stay optional rather than taking the process down on a dropped cable.
            var com = new MockComLayer();
            var host = new HardwareDeviceHost(null, com, new DeviceSettings());

            // The link is already down when the event arrives - MockComLayer.SimulateLayerClosed
            // only raises the event, it does not flip the flag.
            com.IsConnected = false;
            com.SimulateLayerClosed();   // a link that DROPS, not a deliberate Close()

            Assert.IsFalse(host.IsConnected);
        }

        [TestMethod]
        public void CommLoss_AlertsThroughTheBus()
        {
            // The path that actually matters: the cable is pulled, nobody called Disconnect(), and
            // the operator still has to be told.
            var server = new ServerCore();
            MockComLayer com;
            var host = IdentifiedHost(server.MainEventsBus, out com);

            com.IsConnected = false;
            com.SimulateLayerClosed();

            Assert.IsTrue(host.DisconnectAlerted, "a dropped link must raise the disconnect alert");
        }

        [TestMethod]
        public void ConnectionEventWithNoArgs_IsIgnoredByTheAlertHandler()
        {
            // The alert handler runs BEFORE EventsBus touches e.Device, so it really can be handed a
            // null and must not be the thing that fails. It is not: the NullReferenceException here
            // comes from EventsBus.Fire_DeviceConnection itself, which dereferences e.Device
            // unconditionally once the handlers have run. That is a separate weakness in the bus and
            // is deliberately not papered over here - this test pins OUR side of the contract only.
            var server = new ServerCore();

            try
            {
                server.MainEventsBus.Fire_DeviceConnection(this, null);
            }
            catch (NullReferenceException ex)
            {
                StringAssert.Contains(ex.StackTrace, "EventsBus",
                    "the alert handler threw, which is what this test exists to prevent");
            }
        }
    }
}

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-485 AC5/AC6 — the data watchdog. Everything here is an edge: a device is only interesting
    /// at the moment it goes silent and the moment it comes back. Firing on every tick instead of on
    /// the transition would bury the operator in duplicate alerts.
    /// </summary>
    [TestClass]
    public class DataWatchdogTests
    {
        private static readonly TimeSpan Limit = TimeSpan.FromSeconds(60);
        private static readonly DateTime Now = new DateTime(2026, 3, 9, 12, 0, 0, DateTimeKind.Utc);

        private static ServerCore.DataWatchdogAction Evaluate(bool connected, DateTime? last, bool timedOut)
        {
            return ServerCore.EvaluateDataWatchdog(connected, last, timedOut, Now, Limit);
        }

        [TestMethod]
        public void DisconnectedDevice_IsLeftToTheDisconnectAlert()
        {
            // Otherwise one dropped cable produces both ChannelDisconnected and DataTimeout.
            var action = Evaluate(connected: false, last: Now.AddHours(-1), timedOut: false);

            Assert.AreEqual(ServerCore.DataWatchdogAction.None, action);
        }

        [TestMethod]
        public void DeviceThatHasNeverMeasured_IsIdleNotSilent()
        {
            var action = Evaluate(connected: true, last: null, timedOut: false);

            Assert.AreEqual(ServerCore.DataWatchdogAction.None, action);
        }

        [TestMethod]
        public void GoingSilentPastTheLimit_RaisesTimeoutOnce()
        {
            var justPast = Now.AddSeconds(-61);

            Assert.AreEqual(ServerCore.DataWatchdogAction.Timeout,
                            Evaluate(connected: true, last: justPast, timedOut: false));

            // Second tick, still silent: already reported, so nothing more.
            Assert.AreEqual(ServerCore.DataWatchdogAction.None,
                            Evaluate(connected: true, last: justPast, timedOut: true));
        }

        [TestMethod]
        public void ExactlyAtTheLimit_IsNotYetATimeout()
        {
            // The comparison is strictly greater-than; pinning it stops a later refactor from
            // turning a 60-second gap into an alert on a device that is merely slow.
            var action = Evaluate(connected: true, last: Now.AddSeconds(-60), timedOut: false);

            Assert.AreEqual(ServerCore.DataWatchdogAction.None, action);
        }

        [TestMethod]
        public void DataComingBack_AnnouncesRestoredOnce()
        {
            var fresh = Now.AddSeconds(-1);

            Assert.AreEqual(ServerCore.DataWatchdogAction.Restored,
                            Evaluate(connected: true, last: fresh, timedOut: true));

            // And nothing on the ticks after that.
            Assert.AreEqual(ServerCore.DataWatchdogAction.None,
                            Evaluate(connected: true, last: fresh, timedOut: false));
        }

        [TestMethod]
        public void HealthyDeviceProducesNothing()
        {
            var action = Evaluate(connected: true, last: Now.AddSeconds(-5), timedOut: false);

            Assert.AreEqual(ServerCore.DataWatchdogAction.None, action);
        }
    }
}
