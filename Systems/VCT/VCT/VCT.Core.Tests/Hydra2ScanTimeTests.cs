using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.CommServer.CommonBL;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Device.Sessions;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967. Nofar's overnight run of 2026-09-29 had three 48 s gaps. Each was the stale-data
    /// watchdog declaring a stable bath "stalled" - the logger reads to 0.1 °C, so three scans came
    /// back identical - and resetting the logger, although its own scan time moved on by 30 s on
    /// every read. The rest of the unevenness (29/31 s) came from stamping each reading with the
    /// moment it was sent rather than the moment it was scanned. The logger's clock cannot be set to
    /// the second (TIME takes hours and minutes and zeroes the seconds), so it is read and offset.
    /// </summary>
    [TestClass]
    public class Hydra2ScanTimeTests
    {
        private static readonly DateTime Scan = new DateTime(2026, 9, 29, 22, 52, 14);

        #region The stale-data check

        private EventsBus _bus;
        private HardwareDeviceHost _host;

        [TestInitialize]
        public void Setup()
        {
            _bus = new EventsBus();
            _host = new HardwareDeviceHost(_bus, new MockComLayer(), new DeviceSettings());
        }

        private void Broadcast(DateTime? scanTime, DateTime? measuredAt = null, params double[] values)
        {
            var channels = Enumerable.Range(1, values.Length).ToList();
            _host.BroadcastAllMeasurements(channels, values.ToList(), scanTime, measuredAt);
        }

        [TestMethod]
        public void AStableBathIsNotAStall()
        {
            // The night of 2026-09-29, 22:52:14 -> 22:53:14 on the logger's clock: same values, new scans.
            Broadcast(Scan, null, 23.3, 23.4, 23.5);
            var first = _host.LastDistinctMeasurementUtc;

            Thread.Sleep(20);
            Broadcast(Scan.AddSeconds(30), null, 23.3, 23.4, 23.5);
            var second = _host.LastDistinctMeasurementUtc;

            Thread.Sleep(20);
            Broadcast(Scan.AddSeconds(60), null, 23.3, 23.4, 23.5);

            Assert.AreNotEqual(first, second, "a new scan time is a new measurement, whatever its values");
            Assert.AreNotEqual(second, _host.LastDistinctMeasurementUtc);
        }

        [TestMethod]
        public void AReReadLogEntryIsStillAStall()
        {
            // The MBA-962 fault this check exists for: the same entry read again carries its old scan time.
            Broadcast(Scan, null, 20.9917353964817, 21.09);
            var first = _host.LastDistinctMeasurementUtc;

            Thread.Sleep(20);
            Broadcast(Scan, null, 20.9917353964817, 21.09);

            Assert.AreEqual(first, _host.LastDistinctMeasurementUtc);
        }

        [TestMethod]
        public void ALoggerClockSetBackwardsIsStillANewScan()
        {
            // After a re-init the logger's clock is set to the minute, so the next scan time can be earlier.
            Broadcast(Scan, null, 23.0);
            var first = _host.LastDistinctMeasurementUtc;

            Thread.Sleep(20);
            Broadcast(Scan.AddSeconds(-40), null, 23.0);

            Assert.AreNotEqual(first, _host.LastDistinctMeasurementUtc);
        }

        [TestMethod]
        public void TheReadingsTimeTravelsWithThePacket()
        {
            IPacket seen = null;
            _bus.DeviceOnIncomingEvent += (o, e) => seen = e.Packet;
            var measuredAt = new DateTime(2026, 9, 29, 22, 53, 32);

            Broadcast(Scan, measuredAt, 23.3);

            Assert.AreEqual(measuredAt, ((HardwarePacket)seen).MeasuredAt);
        }

        [TestMethod]
        public void WithoutAScanTimeTheOldPacketIsUnchanged()
        {
            IPacket seen = null;
            _bus.DeviceOnIncomingEvent += (o, e) => seen = e.Packet;

            _host.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { 21.5 });

            Assert.IsNull(((HardwarePacket)seen).MeasuredAt);
        }

        #endregion

        #region The Time field

        [TestMethod]
        public void TheTimeFieldIsTheReadingsOwnTime()
        {
            var measuredAt = new DateTime(2026, 9, 29, 22, 53, 32, 400);
            var now = new DateTime(2026, 9, 29, 22, 54, 2);

            Assert.AreEqual("09/29/2026 22:53:32", ServerCore.FormatLoggerDataTime(measuredAt, now));
        }

        [TestMethod]
        public void WithoutOneTheTimeFieldIsTheSendTime()
        {
            var now = new DateTime(2026, 9, 29, 22, 54, 2);

            Assert.AreEqual("09/29/2026 22:54:02", ServerCore.FormatLoggerDataTime(null, now));
        }

        #endregion

        #region Reading the logger's clock

        [TestMethod]
        public void TheClockReplyIsParsed()
        {
            Assert.IsTrue(HydraProtocolHelper.TryBuildDateFromData("19,42,14,9,29,26\r\n", out var clock));
            Assert.AreEqual(new DateTime(2026, 9, 29, 19, 42, 14), clock);

            Assert.IsTrue(HydraProtocolHelper.TryBuildDateFromData("19,42,14,9,29,26=>\r\n", out clock));
            Assert.AreEqual(new DateTime(2026, 9, 29, 19, 42, 14), clock);
        }

        [TestMethod]
        public void ABadClockReplyIsRefusedNotThrown()
        {
            foreach (var reply in new[] { null, "", "=>\r\n", "19,42,14", "19,42,x4,9,29,26", "19,42,14,13,29,26", "25,00,00,9,29,26" })
            {
                Assert.IsFalse(HydraProtocolHelper.TryBuildDateFromData(reply, out _), "reply: " + (reply ?? "null"));
            }
        }

        [TestMethod]
        public void TheOffsetIsCentredOnTheLoggersWholeSecond()
        {
            // 2026-09-29: TIME 19,42 at 19:42:57.7 left the logger about 58 s behind.
            var pc = new DateTime(2026, 9, 29, 19, 43, 12, 0);
            var logger = new DateTime(2026, 9, 29, 19, 42, 14);

            Assert.AreEqual(TimeSpan.FromSeconds(57.5), Hydra2DeviceBL.MeasureLoggerClockOffset(pc, logger));
        }

        [TestMethod]
        public void TheFirstOffsetIsTakenAsItIs()
        {
            Assert.AreEqual(TimeSpan.FromSeconds(57.5), Hydra2DeviceBL.ChooseLoggerClockOffset(null, TimeSpan.FromSeconds(57.5)));
        }

        [TestMethod]
        public void AWholeSecondOfReadingNoiseDoesNotMoveTheOffset()
        {
            // Following it would shift every later reading by a second: the 29/31 s steps again.
            var current = TimeSpan.FromSeconds(57.5);

            Assert.AreEqual(current, Hydra2DeviceBL.ChooseLoggerClockOffset(current, TimeSpan.FromSeconds(58.5)));
            Assert.AreEqual(current, Hydra2DeviceBL.ChooseLoggerClockOffset(current, TimeSpan.FromSeconds(56.5)));
        }

        [TestMethod]
        public void RealDriftMovesTheOffset()
        {
            var current = TimeSpan.FromSeconds(57.5);

            Assert.AreEqual(TimeSpan.FromSeconds(59.5), Hydra2DeviceBL.ChooseLoggerClockOffset(current, TimeSpan.FromSeconds(59.5)));
        }

        [TestMethod]
        public void AScanIsMovedOntoThePcClock()
        {
            // The reported second plus the half second it truncated, plus the offset.
            Assert.AreEqual(Scan.AddSeconds(78.5), Hydra2DeviceBL.ScanTimeOnPcClock(Scan, TimeSpan.FromSeconds(78)));
        }

        [TestMethod]
        public void WithoutAScanTimeOrAnOffsetTheSendTimeIsUsed()
        {
            Assert.IsNull(Hydra2DeviceBL.ScanTimeOnPcClock(default(DateTime), TimeSpan.FromSeconds(78)));
            Assert.IsNull(Hydra2DeviceBL.ScanTimeOnPcClock(Scan, null));
        }

        [TestMethod]
        public void ScansThirtySecondsApartStayThirtySecondsApart()
        {
            // The point of the whole change: the offset is constant, so the spacing is the logger's.
            var offset = TimeSpan.FromSeconds(57.5);
            var a = Hydra2DeviceBL.ScanTimeOnPcClock(Scan, offset).Value;
            var b = Hydra2DeviceBL.ScanTimeOnPcClock(Scan.AddSeconds(30), offset).Value;
            var now = DateTime.Now;

            Assert.AreEqual(TimeSpan.FromSeconds(30), b - a);
            Assert.AreEqual(TimeSpan.FromSeconds(30),
                DateTime.Parse(ServerCore.FormatLoggerDataTime(b, now), System.Globalization.CultureInfo.InvariantCulture)
              - DateTime.Parse(ServerCore.FormatLoggerDataTime(a, now), System.Globalization.CultureInfo.InvariantCulture));
        }

        [TestMethod]
        public void TheClockIsReReadEveryTenMinutes()
        {
            var now = new DateTime(2026, 9, 29, 22, 0, 0, DateTimeKind.Utc);

            Assert.IsTrue(Hydra2DeviceBL.LoggerClockDue(null, now));
            Assert.IsFalse(Hydra2DeviceBL.LoggerClockDue(now.AddMinutes(-9), now));
            Assert.IsTrue(Hydra2DeviceBL.LoggerClockDue(now.AddMinutes(-10), now));
        }

        [TestMethod]
        public void TheTimeSessionHandsBackTheReply()
        {
            var session = new GetSetTimeSession(_host);
            var request = new GetSetDateRequest { Packet = HydraProtocolHelper.Build_GetFullDate() };
            GetSetDateResponse answer = null;
            request.CallBackResponse = (o, e) => answer = e as GetSetDateResponse;

            session.HandleRequest(request);
            session.Timer();
            session.HandlePacket(new HardwarePacket("19,42,14,9,29,26\r\n"));

            Assert.IsNotNull(answer.ResponsePacket, "without the packet the clock reply was unreadable");
            Assert.IsTrue(HydraProtocolHelper.TryBuildDateFromData(answer.ResponsePacket.ToString(), out _));
        }

        #endregion

        #region The Hydra2 BL

        private static LogsResponse Entry(string reply)
        {
            var entry = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            entry.ParseLogResponse(new HardwarePacket("LOGGED? 1\r\n", true), new HardwarePacket(reply), LogsRequest.LogCommands.GetLogs);
            return entry;
        }

        [TestMethod]
        public void EntriesAreOrderedOldestFirst()
        {
            var late = Entry("22,52,44,9,29,26,23.3,0,0,0\r\n");
            var early = Entry("22,52,14,9,29,26,23.4,0,0,0\r\n");

            var ordered = Hydra2DeviceBL.OrderByScanTime(new[] { late, early });

            CollectionAssert.AreEqual(new[] { early, late }, ordered);
        }

        private Hydra2DeviceBL ConnectedBL(out HardwareDeviceHost host, out EventsBus bus)
        {
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            HardwareBL_Settings._settings.Hydra2type.Channels = new List<int> { 1, 2 };

            var blCore = new Hydra2BLCore();
            blCore.Start(new ServerCore());

            bus = new EventsBus();
            var com = new MockComLayer();
            host = new HardwareDeviceHost(bus, com, new DeviceSettings());
            var sn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(sn, 0, sn.Length);

            blCore.OnDeviceConnetion(host);
            host.InitSessions();
            return (Hydra2DeviceBL)host.BL;
        }

        [TestMethod]
        public void EveryWaitingScanIsSentWithItsOwnTime()
        {
            try
            {
                var bl = ConnectedBL(out var host, out var bus);
                var po = new PrivateObject(bl);
                po.SetField("_loggerClockOffset", (TimeSpan?)TimeSpan.FromSeconds(78));
                po.SetField("_pendingLogEntries", 2);

                var sent = new List<HardwarePacket>();
                bus.DeviceOnIncomingEvent += (o, e) => sent.Add((HardwarePacket)e.Packet);

                // Two scans were waiting. The old code sent only the second one to arrive.
                po.Invoke("HandleLogData", Entry("22,52,44,9,29,26,23.3,23.4,0,0,0\r\n"));
                Assert.AreEqual(0, sent.Count, "nothing goes out until the batch is complete");

                po.Invoke("HandleLogData", Entry("22,52,14,9,29,26,23.3,23.4,0,0,0\r\n"));

                Assert.AreEqual(2, sent.Count);
                Assert.AreEqual(Scan.AddSeconds(78.5), sent[0].MeasuredAt, "oldest first, on the PC clock");
                Assert.AreEqual(Scan.AddSeconds(108.5), sent[1].MeasuredAt);
            }
            finally
            {
                HardwareBL_Settings._settings = null;
            }
        }

        [TestMethod]
        public void AFailedReadIsNotSentAsAScan()
        {
            try
            {
                var bl = ConnectedBL(out var host, out var bus);
                var po = new PrivateObject(bl);
                po.SetField("_pendingLogEntries", 1);

                var sent = 0;
                bus.DeviceOnIncomingEvent += (o, e) => sent++;

                po.Invoke("HandleLogData", new LogsResponse(false, LogsRequest.LogCommands.GetLogs));

                Assert.AreEqual(0, sent, "an empty entry would tell the watchdog that a scan arrived");
            }
            finally
            {
                HardwareBL_Settings._settings = null;
            }
        }

        [TestMethod]
        public void TheInitReadsTheLoggersClock()
        {
            // The TIME_DATE? step used to be skipped on every init by a double step-advance.
            try
            {
                var bl = ConnectedBL(out var host, out var bus);
                var po = new PrivateObject(bl);
                po.SetField("_loggerClockReadUtc", (DateTime?)null);

                var state = new SingleState(Hydra2DeviceBL.STATE_MACHINE__Date_Sync) { CurrentStep = 2 };
                var result = po.Invoke("StateWork__Date_Sync", state);

                Assert.AreEqual(SingleState.StepWorkResponses.Skip2NextStep, result);
                Assert.IsNotNull(po.GetField("_loggerClockReadUtc"));

                state.CurrentStep = 3;
                Assert.AreEqual(SingleState.StepWorkResponses.StateFinished, po.Invoke("StateWork__Date_Sync", state));
            }
            finally
            {
                HardwareBL_Settings._settings = null;
            }
        }

        [TestMethod]
        public void TheClockReplySetsTheOffsetAndABadOneKeepsIt()
        {
            try
            {
                var bl = ConnectedBL(out var host, out var bus);
                var po = new PrivateObject(bl);

                var good = new GetSetDateResponse(true) { ResponsePacket = new HardwarePacket(DateTime.Now.ToString("HH,mm,ss,M,d,yy") + "\r\n") };
                po.Invoke("OnLoggerClockRead", good);
                var offset = (TimeSpan?)po.GetField("_loggerClockOffset");
                Assert.IsTrue(offset.HasValue && offset.Value.Duration() < TimeSpan.FromSeconds(3), "offset " + offset);

                po.Invoke("OnLoggerClockRead", new GetSetDateResponse(false));
                Assert.AreEqual(offset, (TimeSpan?)po.GetField("_loggerClockOffset"));
            }
            finally
            {
                HardwareBL_Settings._settings = null;
            }
        }

        #endregion
    }
}
