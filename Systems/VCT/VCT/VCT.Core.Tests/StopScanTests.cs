using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Maba.VCT.Accessories;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.CommServer.CommonBL;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967: "stop scan" in the logger window sends CMD:"Status", Value:Stop, DeviceID:"&lt;logger&gt;".
    /// The logger must stop - no polling loop left, SCAN 0 / LOG_CLR / *RST sent - and stay stopped:
    /// the data watchdog's power-cycle recovery, the calibration graph's re-send of the saved setup and
    /// a reconnect of the link would each have started it again within about a minute. Only the next
    /// Confirm (its Status:Start) sets it up again, even when its configuration is unchanged.
    /// </summary>
    [TestClass]
    public class StopScanTests
    {
        [TestInitialize]
        public void Setup()
        {
            // Another test class may have left a family registered; "no logger identified" means none.
            HardwareBL_Settings.UnregisterActiveFamily(Hydra2DeviceBL.SETTINGS_FAMILY);
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            HardwareBL_Settings._settings.Hydra2type.Channels = new List<int> { 1, 2 };
        }

        [TestCleanup]
        public void Cleanup()
        {
            HardwareBL_Settings.UnregisterActiveFamily(Hydra2DeviceBL.SETTINGS_FAMILY);
            HardwareBL_Settings._settings = null;
        }

        // ------------------------------------------------------------------ the server: routing and when

        private static MyReaderWriterLockSlim<ConcurrentDictionary<string, HardwareDeviceHost>> DeviceHosts(ServerCore server)
        {
            var f = typeof(ServerCore).GetField("DeviceHost_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            return (MyReaderWriterLockSlim<ConcurrentDictionary<string, HardwareDeviceHost>>)f.GetValue(server);
        }

        private static void Tick(ServerCore server, DateTime nowUtc)
        {
            typeof(ServerCore).GetMethod("CheckDataTimeouts", BindingFlags.Instance | BindingFlags.NonPublic)
                              .Invoke(server, new object[] { nowUtc });
        }

        private static void Identify(MockComLayer com)
        {
            var idn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idn, 0, idn.Length);
        }

        /// <summary>An identified logger in the server's device list, driven by a mock Hydra2 BL.</summary>
        private static HardwareDeviceHost Logger(ServerCore server, MockDeviceBL bl, MockComLayer com = null)
        {
            var host = new HardwareDeviceHost(server.MainEventsBus, com ?? new MockComLayer(), new DeviceSettings());
            Identify((MockComLayer)host.InternalComLayer);
            host.InitSessions();
            host.BL = bl;
            DeviceHosts(server).MyWriteLock(d => d.TryAdd(host.SN, host));
            HardwareBL_Settings.RegisterActiveFamily(Hydra2DeviceBL.SETTINGS_FAMILY);
            return host;
        }

        private static MockDeviceBL ScanningBL() => new MockDeviceBL { SettingsFamily = Hydra2DeviceBL.SETTINGS_FAMILY, CanStopScanning = true };

        private static void Status(ServerCore server, string value, string loggerId = "21-337")
        {
            var ws = new WebSocketDeviceHost(server.MainEventsBus, new MockComLayer(), "WS");
            server.MainEventsBus.Fire_OnIncomingEvent(ws, new DeviceEventArgs(ws, new StatusMessage { Value = value, DeviceID = loggerId }));
        }

        [TestMethod]
        public void TheStopIsMarkedOnTheWebSocketThreadAndCarriedOutOnTheTick()
        {
            // It rewinds the BL's state machine, which the tick may be running - so not inline.
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);

            Status(server, "Stop");
            Assert.IsTrue(host.ScanStopped);
            Assert.AreEqual(0, bl.StopScanningCallCount, "stopped inline on the WebSocket thread");

            Tick(server, DateTime.UtcNow);
            Assert.AreEqual(1, bl.StopScanningCallCount);

            Tick(server, DateTime.UtcNow);
            Assert.AreEqual(1, bl.StopScanningCallCount, "a stop is carried out once");
        }

        [TestMethod]
        public void TheWireFormatTheAppSendsReachesTheBL()
        {
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            var ws = new WebSocketDeviceHost(server.MainEventsBus, new MockComLayer(), "WS");
            var parser = new PrivateObject(ws).GetField("ProtocolParser") as Maba.VCT.Common.Protocol_Parser.WebSocketProtocolParaser;

            parser.OnData("CMD:\"Status\", Value:Stop, DeviceID:\"21-337\"");
            Tick(server, DateTime.UtcNow);

            Assert.IsTrue(host.ScanStopped);
            Assert.AreEqual(1, bl.StopScanningCallCount);
        }

        [TestMethod]
        public void AStopWithNoLoggerIdentifiedIsHarmlessAndHoldsNothing()
        {
            var server = new ServerCore();

            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);

            // A logger identified afterwards is not stopped by it.
            var bl = ScanningBL();
            var host = Logger(server, bl);
            Tick(server, DateTime.UtcNow);

            Assert.IsFalse(host.ScanStopped);
            Assert.AreEqual(0, bl.StopScanningCallCount);
        }

        [TestMethod]
        public void TheWatchdogDoesNotRecoverAStoppedLogger()
        {
            // Without the guard: silent past 60 s -> DataTimeout -> power-cycle recovery -> a full
            // init, and the logger scans again a minute after the operator stopped it.
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);

            // A reading that was already on its way when the stop landed.
            host.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { 23.1 });
            var callsBefore = bl.OnConnectionCallCount;
            Tick(server, DateTime.UtcNow.AddMinutes(5));
            Tick(server, DateTime.UtcNow.AddMinutes(10));

            Assert.AreEqual(callsBefore, bl.OnConnectionCallCount, "the stopped logger was re-initialized");
            Assert.IsFalse(host.DataTimedOut, "a deliberate stop is not a data timeout");
        }

        [TestMethod]
        public void TheStopPutsTheWatchdogBackToIdle()
        {
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            host.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { 23.1 });
            host.DataTimedOut = true;
            host.RecoveryAttempts = 3;

            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);

            Assert.IsNull(host.LastMeasurementUtc);
            Assert.IsFalse(host.DataTimedOut);
            Assert.AreEqual(0, host.RecoveryAttempts);
        }

        [TestMethod]
        public void TheGraphsReSendOfTheSavedSetupDoesNotRestartAStoppedLogger()
        {
            var server = new ServerCore();
            var bl = ScanningBL();
            Logger(server, bl);
            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);
            var callsBefore = bl.OnConnectionCallCount;

            server.MainEventsBus.Fire_LiveHardwareReconfigured(null,
                new LiveHardwareReconfiguredEventArgs(Hydra2DeviceBL.SETTINGS_FAMILY, "SensorsAssociation channel change from web app"));
            Tick(server, DateTime.UtcNow);

            Assert.AreEqual(callsBefore, bl.OnConnectionCallCount);
        }

        [TestMethod]
        public void TheNextConfirmRestartsTheScanEvenWithAnUnchangedConfiguration()
        {
            // An unchanged LoggerConfiguration triggers no re-init, so the Start has to.
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);
            var callsBefore = bl.OnConnectionCallCount;

            Status(server, "Start");
            Assert.IsFalse(host.ScanStopped);
            Tick(server, DateTime.UtcNow);

            Assert.AreEqual(callsBefore + 1, bl.OnConnectionCallCount);
            Assert.IsTrue(bl.LastConnectionState);
        }

        [TestMethod]
        public void AStartWithoutAStopChangesNothing()
        {
            var server = new ServerCore();
            var bl = ScanningBL();
            Logger(server, bl);
            var callsBefore = bl.OnConnectionCallCount;

            Status(server, "Start");
            Tick(server, DateTime.UtcNow);

            Assert.AreEqual(callsBefore, bl.OnConnectionCallCount);
        }

        [TestMethod]
        public void AStartBeforeTheStopWasCarriedOutJustRestarts()
        {
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            var callsBefore = bl.OnConnectionCallCount;

            Status(server, "Stop");
            Status(server, "Start");
            Tick(server, DateTime.UtcNow);

            Assert.AreEqual(0, bl.StopScanningCallCount);
            Assert.AreEqual(callsBefore + 1, bl.OnConnectionCallCount);
            Assert.IsFalse(host.ScanStopped);
        }

        [TestMethod]
        public void AStoppedLoggerThatReconnectsIsNotSetUpAgain()
        {
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);
            var callsBefore = bl.OnConnectionCallCount;

            var newCom = new MockComLayer();
            var pending = new HardwareDeviceHost(server.MainEventsBus, newCom, new DeviceSettings());
            Identify(newCom);
            host.InitSessions(pending);

            Assert.AreSame(newCom, host.InternalComLayer);
            Assert.AreEqual(callsBefore, bl.OnConnectionCallCount);
        }

        [TestMethod]
        public void ADeviceWhoseBLDoesNotScanIsNotLeftStopped()
        {
            // Its watchdog must keep working.
            var server = new ServerCore();
            var bl = new MockDeviceBL { SettingsFamily = Hydra2DeviceBL.SETTINGS_FAMILY, CanStopScanning = false };
            var host = Logger(server, bl);

            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);

            Assert.AreEqual(1, bl.StopScanningCallCount);
            Assert.IsFalse(host.ScanStopped);
        }

        // ------------------------------------------------------------------ the Hydra 2625A itself

        private sealed class Hydra
        {
            public HardwareDeviceHost Host;
            public MockComLayer Com;
            public EventsBus Bus;
            public PrivateObject BL;
            public int Generation => (int)BL.GetField("_pollGeneration");
        }

        private static Hydra ConnectedHydra()
        {
            var blCore = new Hydra2BLCore();
            blCore.Start(new ServerCore());

            var hydra = new Hydra { Bus = new EventsBus(), Com = new MockComLayer() };
            hydra.Host = new HardwareDeviceHost(hydra.Bus, hydra.Com, new DeviceSettings());
            Identify(hydra.Com);
            blCore.OnDeviceConnetion(hydra.Host);
            hydra.Host.InitSessions();
            hydra.BL = new PrivateObject((Hydra2DeviceBL)hydra.Host.BL);
            return hydra;
        }

        private static LogsResponse Count(int n)
        {
            var r = new LogsResponse(true, LogsRequest.LogCommands.LogCount);
            r.ParseLogResponse(new HardwarePacket("LOG_COUNT?\r\n", true), new HardwarePacket(n + "\r\n"), LogsRequest.LogCommands.LogCount);
            return r;
        }

        /// <summary>
        /// Runs device ticks until <paramref name="command"/> has gone out. Requests are queued from a
        /// pool thread (HardwareDeviceHost.GetLogs / Reset), so it may take a tick or two to appear.
        /// </summary>
        private static void PumpUntilSent(Hydra hydra, string command)
        {
            var deadline = DateTime.UtcNow.AddSeconds(5);
            while (DateTime.UtcNow < deadline)
            {
                hydra.Host.Timer();
                if (hydra.Com.SentStrings.Any(s => (s ?? "").Trim() == command)) return;
                System.Threading.Thread.Sleep(10);
            }
            Assert.Fail("'{0}' was never sent; sent: {1}", command, string.Join(" | ", hydra.Com.SentStrings.Select(s => s.Trim())));
        }

        private static void Reply(Hydra hydra)
        {
            var ok = System.Text.Encoding.ASCII.GetBytes("\r\n");
            hydra.Com.SimulateDataReceived(ok, 0, ok.Length);
        }

        [TestMethod]
        public void TheStopSendsScan0ThenLogClrThenRst_EachAfterTheLastReply()
        {
            var hydra = ConnectedHydra();
            var before = hydra.Com.SentStrings.Count;

            Assert.IsTrue(hydra.Host.StopScanning("stop scan from web app"));

            PumpUntilSent(hydra, "SCAN 0");
            Reply(hydra);
            PumpUntilSent(hydra, "LOG_CLR");
            Reply(hydra);
            PumpUntilSent(hydra, "*RST");

            // Nothing of the init or the poll goes out around them: the state machine is parked.
            CollectionAssert.AreEqual(new[] { "SCAN 0", "LOG_CLR", "*RST" },
                hydra.Com.SentStrings.Skip(before).Select(s => s.Trim()).ToArray());
        }

        [TestMethod]
        public void TheStopRetiresThePollingLoop()
        {
            var hydra = ConnectedHydra();
            var loop = hydra.Generation;

            hydra.Host.StopScanning("stop scan from web app");

            Assert.AreEqual(loop + 1, hydra.Generation);
            // The loop's LOG_COUNT? answer arrives: 1 scan waiting. It must not read it.
            hydra.BL.Invoke("LogResponseCallBack", Count(1), loop);
            Assert.AreEqual(0, (int)hydra.BL.GetField("_pendingLogEntries"));
            // A loop asleep in its 28 s wait checks this when it wakes, and stops.
            Assert.IsTrue((bool)hydra.BL.Invoke("IsStalePoll", loop, "the 28 s wait"));
        }

        [TestMethod]
        public void TheStopDropsABatchHalfRead()
        {
            var hydra = ConnectedHydra();
            var loop = hydra.Generation;
            hydra.BL.Invoke("LogResponseCallBack", Count(2), loop);
            var sent = 0;
            hydra.Bus.DeviceOnIncomingEvent += (o, e) => sent++;

            hydra.Host.StopScanning("stop scan from web app");

            var entry = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            entry.ParseLogResponse(new HardwarePacket("LOGGED? 1\r\n", true), new HardwarePacket("22,52,14,9,29,26,23.3,23.4,0,0,0\r\n"), LogsRequest.LogCommands.GetLogs);
            hydra.BL.Invoke("HandleLogData", entry, loop);

            Assert.AreEqual(0, sent);
            Assert.AreEqual(0, (int)hydra.BL.GetField("_pendingLogEntries"));
        }

        [TestMethod]
        public void TheStopParksTheInitAndTheNextConfirmsReInitStartsItAgain()
        {
            var hydra = ConnectedHydra();

            hydra.Host.StopScanning("stop scan from web app");
            Assert.AreEqual(BaseBLDevice.DeviceSteps.Close, hydra.BL.GetProperty("CurrentStep"),
                "an init half way through would go on to start a polling loop");

            var stopped = hydra.Generation;
            Assert.IsTrue(hydra.Host.ReinitializeBL("scan confirmed again after a stop"));

            Assert.AreEqual(BaseBLDevice.DeviceSteps.Start, hydra.BL.GetProperty("CurrentStep"));
            Assert.AreEqual(stopped + 1, hydra.Generation, "the re-init starts a new loop");
        }

        [TestMethod]
        public void AReInitBeforeTheStopSequenceEndsCutsItShort()
        {
            // The next Confirm can come while SCAN 0 / LOG_CLR are still on their way; the init's
            // own *RST follows, so the rest of the stop is not sent on top of it.
            var hydra = ConnectedHydra();
            hydra.Host.StopScanning("stop scan from web app");
            var stopGeneration = hydra.Generation;
            PumpUntilSent(hydra, "SCAN 0");

            hydra.Host.ReinitializeBL("scan confirmed again after a stop");
            var sentBefore = hydra.Com.SentStrings.Count;
            hydra.BL.Invoke("SendStopCommand", 1, stopGeneration);
            for (var i = 0; i < 5; i++) { hydra.Host.Timer(); System.Threading.Thread.Sleep(10); }

            Assert.IsFalse(hydra.Com.SentStrings.Skip(sentBefore).Any(s => s.Trim() == "LOG_CLR"));
        }
    }
}
