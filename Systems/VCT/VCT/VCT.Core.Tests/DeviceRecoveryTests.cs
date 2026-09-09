using System;
using System.Text.RegularExpressions;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-962 — power-cycle recovery. A logger that loses power and comes back has forgotten its
    /// scan configuration while its serial port stayed open the whole time: it reports connected,
    /// produces nothing, and no discovery pass can find it because the port is still held. The only
    /// way back is to re-send the setup sequence, and the only interesting parts of deciding to do
    /// that are the edges and the bound — neither of which is reachable in a test that needs a real
    /// instrument on a real port.
    /// </summary>
    [TestClass]
    public class DeviceRecoveryTests
    {
        private static readonly DateTime Now = new DateTime(2026, 3, 9, 12, 0, 0, DateTimeKind.Utc);
        private static readonly TimeSpan Retry = TimeSpan.FromSeconds(60);
        private const int MaxAttempts = 5;

        private static bool Should(bool connected, bool timedOut, DateTime? lastAttempt, int attempts)
        {
            return ServerCore.ShouldAttemptRecovery(connected, timedOut, lastAttempt, attempts,
                                                    MaxAttempts, Now, Retry);
        }

        [TestMethod]
        public void DisconnectedDevice_IsNotRecovered()
        {
            // There is nothing to re-initialize into: the link itself is gone, which is the
            // ChannelDisconnected case and a different repair entirely.
            Assert.IsFalse(Should(connected: false, timedOut: true, lastAttempt: null, attempts: 0));
        }

        [TestMethod]
        public void HealthyDevice_IsLeftAlone()
        {
            Assert.IsFalse(Should(connected: true, timedOut: false, lastAttempt: null, attempts: 0));
        }

        [TestMethod]
        public void FirstAttemptGoesOutImmediately()
        {
            // On the same tick the watchdog declared the silence. A power cycle is over long before
            // 60 seconds have passed, so waiting another minute only costs the operator a minute.
            Assert.IsTrue(Should(connected: true, timedOut: true, lastAttempt: null, attempts: 0));
        }

        [TestMethod]
        public void SecondAttemptWaitsForTheRetryInterval()
        {
            Assert.IsFalse(Should(connected: true, timedOut: true, lastAttempt: Now.AddSeconds(-59), attempts: 1),
                           "a retry inside the interval would re-read the master corrections every tick");

            Assert.IsTrue(Should(connected: true, timedOut: true, lastAttempt: Now.AddSeconds(-60), attempts: 1));
        }

        [TestMethod]
        public void AttemptsAreBounded()
        {
            // A device that is simply switched off would otherwise be re-initialized every minute for
            // as long as the server runs, each attempt going back to SQL for the master corrections.
            Assert.IsTrue(Should(connected: true, timedOut: true, lastAttempt: Now.AddMinutes(-5), attempts: MaxAttempts - 1));
            Assert.IsFalse(Should(connected: true, timedOut: true, lastAttempt: Now.AddMinutes(-5), attempts: MaxAttempts));
            Assert.IsFalse(Should(connected: true, timedOut: true, lastAttempt: Now.AddHours(-3), attempts: MaxAttempts + 1));
        }
    }

    /// <summary>
    /// MBA-962 — the two things a device host gained: a way for its BL to report a fault only the BL
    /// can see, and a way to be restarted in place after a power cycle.
    /// </summary>
    [TestClass]
    public class HardwareDeviceHostRecoveryTests
    {
        private EventsBus _bus;
        private MockComLayer _comLayer;
        private HardwareDeviceHost _host;

        [TestInitialize]
        public void Setup()
        {
            _bus = new EventsBus();
            _comLayer = new MockComLayer();
            _host = new HardwareDeviceHost(_bus, _comLayer, new DeviceSettings());
        }

        [TestMethod]
        public void RaiseAlert_ReachesTheBusWithItsChannel()
        {
            DeviceAlertEventArgs seen = null;
            _bus.DeviceAlert += (o, e) => seen = e;

            _host.RaiseAlert("ChannelDisconnected", "Channel 3 disconnected - no sensor detected", "3");

            Assert.IsNotNull(seen, "the BL's alert never reached the bus");
            Assert.AreEqual("ChannelDisconnected", seen.AlertType);
            Assert.AreEqual("3", seen.Channel);
            Assert.AreSame(_host, seen.Device);
        }

        [TestMethod]
        public void RaiseAlert_WithNobodyListening_DoesNotThrow()
        {
            // It is called from inside the measurement loop. Throwing there would cost the readings
            // of every other channel in the same scan.
            _host.RaiseAlert("ChannelDisconnected", "Channel 3 disconnected", "3");
        }

        [TestMethod]
        public void ReinitializeBL_RestartsTheBL()
        {
            var bl = new MockDeviceBL();
            _host.BL = bl;

            Assert.IsTrue(_host.ReinitializeBL("test"));
            Assert.IsTrue(bl.OnConnectionCalled);
            Assert.IsTrue(bl.LastConnectionState, "the restart has to look like a connection, not a drop");
        }

        [TestMethod]
        public void ReinitializeBL_WithNoBL_SaysSoRatherThanThrowing()
        {
            // The caller logs the difference between "recovery attempted" and "nothing to recover";
            // a device that timed out before a BL was ever attached is the second.
            Assert.IsFalse(_host.ReinitializeBL("test"));
        }
    }

    /// <summary>
    /// MBA-962 — the channel an alert is about. The web app builds its disconnect ranges from the
    /// key deviceId:channel and closes a range only when a DataRestored arrives on that same key, so
    /// a per-channel alert that does not name its channel is filed against a device-wide "ALL"
    /// range and the operator sees the wrong graph shaded — or none at all.
    /// </summary>
    [TestClass]
    public class AlertChannelFieldTests
    {
        private static readonly Regex ChannelField = new Regex("Channel:\"([^\"]+)\"");
        private static readonly DateTime SampleTime = new DateTime(2026, 3, 9, 7, 5, 4);

        private static string ChannelOf(string channel)
        {
            var msg = ServerCore.BuildAlertMessage("SN-1234", "SN-1234", "LIVE", "ChannelDisconnected",
                                                   "Channel 3 disconnected - no sensor detected",
                                                   SampleTime, channel);
            var m = ChannelField.Match(msg);
            Assert.IsTrue(m.Success, "the app drops an alert whose Channel field is missing or empty");
            return m.Groups[1].Value;
        }

        [TestMethod]
        public void AChannelAlertCarriesItsChannelNumber()
        {
            Assert.AreEqual("3", ChannelOf("3"));
        }

        [TestMethod]
        public void ADeviceWideAlertStillReadsALL()
        {
            // The existing device-level alerts pass nothing, and their pairing under SN:ALL is what
            // makes DataTimeout/DataRestored line up today.
            var msg = ServerCore.BuildAlertMessage("SN-1234", "SN-1234", "LIVE", "DataTimeout",
                                                   "No data received for 60 seconds", SampleTime);

            Assert.AreEqual("ALL", ChannelField.Match(msg).Groups[1].Value);
        }

        [TestMethod]
        public void ABlankChannelFallsBackRatherThanEmittingAnEmptyField()
        {
            // parse-alert-message returns null on the first blank field, taking the whole alert with
            // it. A caller that passes "" or " " must still produce something the app will accept.
            Assert.AreEqual("ALL", ChannelOf(""));
            Assert.AreEqual("ALL", ChannelOf("   "));
        }
    }
}
