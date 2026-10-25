using System;
using System.Collections.Generic;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967, bench 2026-09-30: a Confirm at 14:50:27, 23 s after a reading, restarted the scan and put
    /// the next reading at 14:51:07. The watchdog still counted from 14:50:04 and fired "No data received
    /// for 60 seconds" at 14:51:04; its power-cycle recovery then reset the healthy logger a second time,
    /// and the operator saw 100 s without data. An operator's reconfiguration now restarts the clock.
    /// </summary>
    [TestClass]
    public class ReconfigurationWatchdogTests
    {
        private static readonly TimeSpan Limit = TimeSpan.FromSeconds(60);
        private HardwareDeviceHost _host;

        [TestInitialize]
        public void Setup()
        {
            _host = new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings());
        }

        private void Broadcast() => _host.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { 23.1 });

        [TestMethod]
        public void TheSilenceAReconfigurationCausesIsNotATimeout()
        {
            Broadcast();
            var reconfiguredAt = _host.LastMeasurementUtc.Value.AddSeconds(23);

            Assert.IsTrue(_host.RestartWatchdogClockForReconfiguration(reconfiguredAt));

            // 60 s after the last reading, but only 37 s after the restart - the bench's false alarm.
            var falseAlarmTime = reconfiguredAt.AddSeconds(37);
            Assert.AreEqual(ServerCore.DataWatchdogAction.None,
                ServerCore.EvaluateDataWatchdog(true, _host.WatchdogMeasurementUtc, false, falseAlarmTime, Limit));
        }

        [TestMethod]
        public void ALoggerThatNeverComesBackIsStillCaught()
        {
            Broadcast();
            var reconfiguredAt = _host.LastMeasurementUtc.Value.AddSeconds(23);
            _host.RestartWatchdogClockForReconfiguration(reconfiguredAt);

            Assert.AreEqual(ServerCore.DataWatchdogAction.Timeout,
                ServerCore.EvaluateDataWatchdog(true, _host.WatchdogMeasurementUtc, false, reconfiguredAt.AddSeconds(61), Limit));
        }

        [TestMethod]
        public void TheStaleDataClockRestartsToo()
        {
            _host.StaleDataDetectionEnabled = true;
            Broadcast();
            var reconfiguredAt = _host.LastMeasurementUtc.Value.AddSeconds(23);

            _host.RestartWatchdogClockForReconfiguration(reconfiguredAt);

            Assert.AreEqual(reconfiguredAt, _host.WatchdogMeasurementUtc);
        }

        [TestMethod]
        public void ADeviceAlreadyDeclaredSilentKeepsItsClock()
        {
            // Restarting it would hide the fault and make the watchdog announce a recovery that has not happened.
            Broadcast();
            var lastReading = _host.LastMeasurementUtc;
            _host.DataTimedOut = true;

            Assert.IsFalse(_host.RestartWatchdogClockForReconfiguration(lastReading.Value.AddSeconds(90)));
            Assert.AreEqual(lastReading, _host.LastMeasurementUtc);
        }

        [TestMethod]
        public void ADeviceThatNeverMeasuredStaysIdle()
        {
            // Null means "not scanning yet", which the watchdog deliberately does not watch.
            Assert.IsFalse(_host.RestartWatchdogClockForReconfiguration(DateTime.UtcNow));
            Assert.IsNull(_host.LastMeasurementUtc);
        }
    }
}
