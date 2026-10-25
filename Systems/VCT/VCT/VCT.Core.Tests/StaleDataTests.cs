using System;
using System.Collections.Generic;
using System.Threading;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-962, the communication case. Pulling the logger's cable did not produce a disconnect -
    /// the serial port stayed open - so nothing looked wrong to any part of the server. What
    /// actually happened is that the instrument's log buffer stopped advancing and the same entries
    /// were read and re-broadcast: on the station, <c>1,20.9917353964817</c> unchanged to thirteen
    /// decimal places, every 34 seconds, for minutes. The watchdog asked only whether a broadcast
    /// had happened, so it counted that as a healthy device, and the recovery that would have
    /// restarted the scan never ran. The operator saw readings that never moved.
    /// </summary>
    [TestClass]
    public class StaleDataTests
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

        private void Broadcast(params double[] values)
        {
            var channels = new List<int>();
            var vals = new List<double>();
            for (int i = 0; i < values.Length; i++) { channels.Add(i + 1); vals.Add(values[i]); }
            _host.BroadcastAllMeasurements(channels, vals);
        }

        [TestMethod]
        public void ARepeatedReadingDoesNotCountAsFreshData()
        {
            Broadcast(20.9917353964817, 21.09);
            var first = _host.LastDistinctMeasurementUtc;
            Assert.IsNotNull(first);

            Thread.Sleep(20);
            Broadcast(20.9917353964817, 21.09);

            Assert.AreEqual(first, _host.LastDistinctMeasurementUtc,
                            "the same values arriving again is the buffer being re-read, not a new measurement");
        }

        [TestMethod]
        public void AChangedReadingIsFreshData()
        {
            Broadcast(20.9917353964817, 21.09);
            var first = _host.LastDistinctMeasurementUtc;

            Thread.Sleep(20);
            Broadcast(20.9917353964818, 21.09);   // the last digit is enough - that is what noise moves

            Assert.AreNotEqual(first, _host.LastDistinctMeasurementUtc);
        }

        [TestMethod]
        public void ARepeatIsStillBroadcastToTheClients()
        {
            // A stuck value is a fault to report, not a reason to blank the operator's screen.
            var seen = 0;
            _bus.DeviceOnIncomingEvent += (o, e) => seen++;

            Broadcast(21.5);
            Broadcast(21.5);

            Assert.AreEqual(2, seen);
        }

        [TestMethod]
        public void TheWatchdogIgnoresRepeatsOnlyWhereTheBLAsksItTo()
        {
            Broadcast(21.5);
            Thread.Sleep(20);
            Broadcast(21.5);

            // A source repeats its setpoint on purpose, so for it the plain "did anything arrive"
            // timestamp is the honest one.
            _host.StaleDataDetectionEnabled = false;
            Assert.AreEqual(_host.LastMeasurementUtc, _host.WatchdogMeasurementUtc);

            _host.StaleDataDetectionEnabled = true;
            Assert.AreEqual(_host.LastDistinctMeasurementUtc, _host.WatchdogMeasurementUtc);
            Assert.AreNotEqual(_host.LastMeasurementUtc, _host.WatchdogMeasurementUtc,
                               "the whole point: the device answered, but it did not measure");
        }

        [TestMethod]
        public void AStalledLoggerReachesTheTimeoutTheSameWayASilentOneDoes()
        {
            // The stall feeds the existing watchdog, so the alert, the edge detection and the
            // recovery attempt are the ones already proven for a silent device.
            var now = new DateTime(2026, 9, 10, 12, 0, 0, DateTimeKind.Utc);
            var stuckSince = now.AddSeconds(-61);

            Assert.AreEqual(ServerCore.DataWatchdogAction.Timeout,
                            ServerCore.EvaluateDataWatchdog(true, stuckSince, false, now, TimeSpan.FromSeconds(60)));
        }

        [TestMethod]
        public void TheOperatorIsToldWhichOfTheTwoFaultsItIs()
        {
            var now = new DateTime(2026, 9, 10, 12, 0, 0, DateTimeKind.Utc);
            var limit = TimeSpan.FromSeconds(60);

            // Still answering, still repeating itself: the words have to say so, because the app has
            // only one alert type for both.
            _host.StaleDataDetectionEnabled = true;
            Broadcast(21.5);
            StringAssert.Contains(ServerCore.DescribeDataFault(_host, limit, DateTime.UtcNow),
                                  "repeated the same reading");

            // Genuinely silent - nothing has arrived inside the window.
            _host.StaleDataDetectionEnabled = false;
            StringAssert.Contains(ServerCore.DescribeDataFault(_host, limit, now), "No data received");
        }

        [TestMethod]
        public void RecoveryDoesNotClearTheStallTimestamp()
        {
            // Deliberate. ReinitializeBL restarts the instrument; whether that worked is decided by
            // the readings that follow, not by the restart itself. Clearing the timestamp here would
            // reset it to "never measured", which the watchdog reads as an idle device - the station
            // would stay stuck with the alert already raised and no further attempt, and nothing
            // would ever announce the recovery.
            _host.StaleDataDetectionEnabled = true;
            Broadcast(21.5);
            var stuckSince = _host.LastDistinctMeasurementUtc;

            _host.BL = new MockDeviceBL();
            Assert.IsTrue(_host.ReinitializeBL("stalled scan"));

            Assert.AreEqual(stuckSince, _host.LastDistinctMeasurementUtc);
        }
    }
}
