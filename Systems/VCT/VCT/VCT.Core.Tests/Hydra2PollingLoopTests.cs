using System;
using System.Collections.Generic;
using Maba.VCT.Common;
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
    /// MBA-967, "the scan starts but no data is recorded until the software is restarted". Every
    /// init starts a polling loop, and a re-init only drops the request in flight: a loop asleep in
    /// its 28 s wait woke up afterwards and polled beside the new one. In Nofar's logs the LOG_COUNT?
    /// rate climbed from 2 to 7 per 30 s as app-driven re-inits piled up, and one loop's LOG_CLR
    /// landed between another's LOG_COUNT? and LOGGED? - the logger answered "!>" and the scan was
    /// lost, 1,291 times between 14 and 30 September. Only a restart brought it back to one loop.
    /// </summary>
    [TestClass]
    public class Hydra2PollingLoopTests
    {
        private HardwareDeviceHost _host;
        private EventsBus _bus;
        private PrivateObject _bl;

        [TestInitialize]
        public void Setup()
        {
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            HardwareBL_Settings._settings.Hydra2type.Channels = new List<int> { 1, 2 };

            var blCore = new Hydra2BLCore();
            blCore.Start(new ServerCore());

            _bus = new EventsBus();
            var com = new MockComLayer();
            _host = new HardwareDeviceHost(_bus, com, new DeviceSettings());
            var sn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(sn, 0, sn.Length);

            blCore.OnDeviceConnetion(_host);
            _host.InitSessions();
            _bl = new PrivateObject((Hydra2DeviceBL)_host.BL);
        }

        [TestCleanup]
        public void Cleanup()
        {
            HardwareBL_Settings.UnregisterActiveFamily(Hydra2DeviceBL.SETTINGS_FAMILY);
            HardwareBL_Settings._settings = null;
        }

        private int Generation => (int)_bl.GetField("_pollGeneration");

        private static LogsResponse Count(int n)
        {
            var r = new LogsResponse(true, LogsRequest.LogCommands.LogCount);
            r.ParseLogResponse(new HardwarePacket("LOG_COUNT?\r\n", true), new HardwarePacket(n + "\r\n"), LogsRequest.LogCommands.LogCount);
            return r;
        }

        private static LogsResponse Entry(string reply)
        {
            var r = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            r.ParseLogResponse(new HardwarePacket("LOGGED? 1\r\n", true), new HardwarePacket(reply), LogsRequest.LogCommands.GetLogs);
            return r;
        }

        [TestMethod]
        public void EveryInitStartsANewLoop()
        {
            var before = Generation;

            Assert.IsTrue(_host.ReinitializeBL("LoggerConfiguration change from web app"));

            Assert.AreEqual(before + 1, Generation);
        }

        [TestMethod]
        public void AnOldLoopThatWakesAfterAReInitDoesNotPoll()
        {
            var oldLoop = Generation;
            _host.ReinitializeBL("LoggerConfiguration change from web app");

            // The old loop's LOG_COUNT? answer arrives: 1 scan waiting. Acting on it is what queued the
            // LOGGED? that a newer loop's LOG_CLR then emptied.
            _bl.Invoke("LogResponseCallBack", Count(1), oldLoop);

            Assert.AreEqual(0, (int)_bl.GetField("_pendingLogEntries"), "the old loop must not start a read");
        }

        [TestMethod]
        public void TheLiveLoopStillReads()
        {
            _bl.Invoke("LogResponseCallBack", Count(1), Generation);

            Assert.AreEqual(1, (int)_bl.GetField("_pendingLogEntries"));
        }

        [TestMethod]
        public void AnOldLoopsEntryIsNotBroadcastAndDoesNotClearTheLogger()
        {
            var oldLoop = Generation;
            _host.ReinitializeBL("LoggerConfiguration change from web app");
            _bl.SetField("_pendingLogEntries", 1);

            var sent = 0;
            _bus.DeviceOnIncomingEvent += (o, e) => sent++;

            _bl.Invoke("HandleLogData", Entry("22,52,14,9,29,26,23.3,23.4,0,0,0\r\n"), oldLoop);

            Assert.AreEqual(0, sent);
            Assert.AreEqual(1, (int)_bl.GetField("_pendingLogEntries"), "the live loop's batch is left alone");
        }

        [TestMethod]
        public void TheLiveLoopsEntryIsBroadcast()
        {
            _bl.SetField("_pendingLogEntries", 1);
            var sent = 0;
            _bus.DeviceOnIncomingEvent += (o, e) => sent++;

            _bl.Invoke("HandleLogData", Entry("22,52,14,9,29,26,23.3,23.4,0,0,0\r\n"), Generation);

            Assert.AreEqual(1, sent);
        }

        /// <summary>
        /// PR #20 review: the batch is cleared only after it is sent, and polling carries on when that
        /// LOG_CLR fails, so the next poll reads the old entries again beside the new one. Each failed
        /// clear used to re-send them all, with their old times - a growing run of duplicates whose
        /// times ran backwards in the app.
        /// </summary>
        [TestMethod]
        public void AScanStillInTheLoggerAfterAFailedClearIsNotSentAgain()
        {
            _bl.SetField("_loggerClockOffset", (TimeSpan?)TimeSpan.Zero);
            var times = new List<DateTime?>();
            _bus.DeviceOnIncomingEvent += (o, e) => times.Add(((HardwarePacket)e.Packet).MeasuredAt);

            _bl.SetField("_pendingLogEntries", 1);
            _bl.Invoke("HandleLogData", Entry("22,52,14,9,29,26,23.3,23.4,0,0,0\r\n"), Generation);
            _bl.Invoke("LogClearAfterReadCallback", new LogsResponse(false, LogsRequest.LogCommands.ClearLogs), Generation);

            // The next poll: the uncleared scan, then the new one.
            _bl.SetField("_pendingLogEntries", 2);
            _bl.Invoke("HandleLogData", Entry("22,52,14,9,29,26,23.3,23.4,0,0,0\r\n"), Generation);
            _bl.Invoke("HandleLogData", Entry("22,52,44,9,29,26,23.3,23.4,0,0,0\r\n"), Generation);

            CollectionAssert.AreEqual(new List<DateTime?>
            {
                new DateTime(2026, 9, 29, 22, 52, 14, 500),
                new DateTime(2026, 9, 29, 22, 52, 44, 500),
            }, times);
        }

        [TestMethod]
        public void AfterAReInitAnEarlierScanTimeIsANewScan()
        {
            // TIME puts the logger's clock back to the minute, so the first scan after a re-init can
            // carry an earlier time than the last one sent before it.
            _bl.SetField("_pendingLogEntries", 1);
            _bl.Invoke("HandleLogData", Entry("22,52,44,9,29,26,23.3,23.4,0,0,0\r\n"), Generation);

            _host.ReinitializeBL("LoggerConfiguration change from web app");
            var sent = 0;
            _bus.DeviceOnIncomingEvent += (o, e) => sent++;

            _bl.SetField("_pendingLogEntries", 1);
            _bl.Invoke("HandleLogData", Entry("22,52,30,9,29,26,23.3,23.4,0,0,0\r\n"), Generation);

            Assert.AreEqual(1, sent);
        }
    }
}
