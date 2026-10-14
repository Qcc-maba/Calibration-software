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

            Assert.AreEqual(0, bl.StopScanningCallCount, "asked whether it can stop, not told to");
            Assert.IsFalse(host.ScanStopped);
        }

        [TestMethod]
        public void ADeviceWhoseBLDoesNotScanIsReallyLeftAsItWas()
        {
            // Review of #28: the BL is asked before anything is cleared, so the watchdog keeps judging
            // the device from its last reading and its recovery budget is not handed back.
            var server = new ServerCore();
            var bl = new MockDeviceBL { SettingsFamily = Hydra2DeviceBL.SETTINGS_FAMILY, CanStopScanning = false };
            var host = Logger(server, bl);
            host.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { 23.1 });
            var lastReading = host.LastMeasurementUtc;
            host.DataTimedOut = true;
            host.RecoveryAttempts = 3;
            host.RequestStopScanning("stop scan from web app");

            Assert.IsFalse(host.StopScanning(host.TakePendingStopReason()));

            Assert.AreEqual(lastReading, host.LastMeasurementUtc);
            Assert.IsTrue(host.DataTimedOut);
            Assert.AreEqual(3, host.RecoveryAttempts);
            Assert.IsFalse(host.ScanStopped);
        }

        [TestMethod]
        public void ABLThatClaimsItCanStopAndThenDoesNotIsNotHeldStopped()
        {
            var server = new ServerCore();
            var bl = new MockDeviceBL { SettingsFamily = Hydra2DeviceBL.SETTINGS_FAMILY, CanStopScanning = true, StopScanningFails = true };
            var host = Logger(server, bl);
            host.RequestStopScanning("stop scan from web app");

            Assert.IsFalse(host.StopScanning(host.TakePendingStopReason()));

            Assert.AreEqual(1, bl.StopScanningCallCount);
            Assert.IsFalse(host.ScanStopped);
        }

        [TestMethod]
        public void ADeviceWithNoBLHasNothingToStop()
        {
            var host = new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings());
            Identify((MockComLayer)host.InternalComLayer);
            host.RequestStopScanning("stop scan from web app");

            Assert.IsFalse(host.StopScanning(host.TakePendingStopReason()));
            Assert.IsFalse(host.ScanStopped);
        }

        [TestMethod]
        public void AStopOrResumeWithoutAReasonGetsADefaultOne()
        {
            var host = new HardwareDeviceHost(new EventsBus(), new MockComLayer(), new DeviceSettings());

            host.RequestStopScanning(null);
            Assert.AreEqual("stop scan from web app", host.TakePendingStopReason());

            Assert.IsTrue(host.RequestResumeScanning(null));
            Assert.AreEqual("scan resumed from web app", host.TakePendingReconfigureReason());
        }

        /// <summary>The device's link drops and a new one is promoted to it, as DeviceTick does.</summary>
        private static MockComLayer Reconnect(HardwareDeviceHost host, EventsBus bus)
        {
            var newCom = new MockComLayer();
            var pending = new HardwareDeviceHost(bus, newCom, new DeviceSettings());
            Identify(newCom);
            host.InitSessions(pending);
            pending.ReplaceComLayer(null);
            return newCom;
        }

        [TestMethod]
        public void AStoppedLoggerThatReconnectsIsSentTheStopAgain()
        {
            // Review of #28: a stop carried out with the link down never reached the logger, which
            // goes on scanning into its own memory. The reconnect is when it can be told.
            var server = new ServerCore();
            var bl = ScanningBL();
            var host = Logger(server, bl);
            Status(server, "Stop");
            Tick(server, DateTime.UtcNow);
            var callsBefore = bl.OnConnectionCallCount;

            Reconnect(host, server.MainEventsBus);
            Assert.AreEqual(2, bl.StopScanningCallCount);
            Assert.AreEqual("reconnected while its scan is stopped", bl.LastStopReason);

            Reconnect(host, server.MainEventsBus);
            Assert.AreEqual(3, bl.StopScanningCallCount, "on every reconnect while stopped");
            Assert.AreEqual(callsBefore, bl.OnConnectionCallCount, "set up again");
            Assert.IsTrue(host.ScanStopped);
        }

        [TestMethod]
        public void AReconnectWhoseStopThrowsIsLoggedAndStillDoesNotSetItUp()
        {
            var server = new ServerCore();
            var bl = new MockDeviceBL { SettingsFamily = Hydra2DeviceBL.SETTINGS_FAMILY, CanStopScanning = true, StopScanningThrows = true };
            var host = Logger(server, bl);
            host.RequestStopScanning("stop scan from web app");
            var callsBefore = bl.OnConnectionCallCount;

            Reconnect(host, server.MainEventsBus);

            Assert.AreEqual(callsBefore, bl.OnConnectionCallCount);
            Assert.IsTrue(host.ScanStopped);
        }

        [TestMethod]
        public void AReconnectOfADeviceThatCannotStopSetsItUpAsUsual()
        {
            // Marked stopped by a Stop the tick has not carried out yet; its BL has no scan to stop,
            // so the tick will clear the mark - it must not come back unconfigured meanwhile.
            var server = new ServerCore();
            var bl = new MockDeviceBL { SettingsFamily = Hydra2DeviceBL.SETTINGS_FAMILY, CanStopScanning = false };
            var host = Logger(server, bl);
            host.RequestStopScanning("stop scan from web app");
            var callsBefore = bl.OnConnectionCallCount;

            Reconnect(host, server.MainEventsBus);

            Assert.AreEqual(callsBefore + 1, bl.OnConnectionCallCount);
            Assert.AreEqual(0, bl.StopScanningCallCount);
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
            hydra.BL.Invoke("SendStopCommand", 1, stopGeneration, new List<string>());
            for (var i = 0; i < 5; i++) { hydra.Host.Timer(); System.Threading.Thread.Sleep(10); }

            Assert.IsFalse(hydra.Com.SentStrings.Skip(sentBefore).Any(s => s.Trim() == "LOG_CLR"));
        }

        // ------------------------------------------------------------------ the link down (review of #28)

        /// <summary>Captures what the server logs, for the lines an operator reads to know what happened.</summary>
        private sealed class LogCapture : IDisposable
        {
            private readonly System.IO.TextWriter _previous;
            private readonly System.IO.StringWriter _log = new System.IO.StringWriter();

            public LogCapture()
            {
                _previous = Maba.VCT.Libs.Trace.Tracer.CurrentTracer.OutputStream;
                Maba.VCT.Libs.Trace.Tracer.CurrentTracer.OutputStream = System.IO.TextWriter.Synchronized(_log);
            }

            public string Text { get { lock (_log) return _log.ToString(); } }

            /// <summary>Waits for a line logged from a reply callback, which runs on a pool thread.</summary>
            public bool WaitFor(string fragment, int milliseconds = 5000)
            {
                var deadline = DateTime.UtcNow.AddMilliseconds(milliseconds);
                while (DateTime.UtcNow < deadline)
                {
                    if (Text.Contains(fragment)) return true;
                    System.Threading.Thread.Sleep(10);
                }
                return false;
            }

            public void Dispose() { Maba.VCT.Libs.Trace.Tracer.CurrentTracer.OutputStream = _previous; }
        }

        private const string StoppedLine = "[HYDRA Stop] The logger is stopped";

        private static void Pump(Hydra hydra, int ticks = 10)
        {
            for (var i = 0; i < ticks; i++) { hydra.Host.Timer(); System.Threading.Thread.Sleep(10); }
        }

        /// <summary>A stop carried out the way the tick does it, while the logger's link is down.</summary>
        private static void StopWhileUnplugged(Hydra hydra)
        {
            hydra.Com.IsConnected = false;
            hydra.Host.RequestStopScanning("stop scan from web app");
            Assert.IsTrue(hydra.Host.StopScanning(hydra.Host.TakePendingStopReason()));
        }

        /// <summary>The logger's link comes back on a new port, as DeviceTick promotes it.</summary>
        private static void Replug(Hydra hydra)
        {
            hydra.Com = new MockComLayer();
            var pending = new HardwareDeviceHost(hydra.Bus, hydra.Com, new DeviceSettings());
            Identify(hydra.Com);
            hydra.Host.InitSessions(pending);
            pending.ReplaceComLayer(null);
        }

        [TestMethod]
        public void AStopWithTheLinkDownSendsNothingAndSaysSo()
        {
            var hydra = ConnectedHydra();
            using (var log = new LogCapture())
            {
                StopWhileUnplugged(hydra);
                Pump(hydra);

                Assert.AreEqual(0, hydra.Com.SentStrings.Count);
                StringAssert.Contains(log.Text, "[HYDRA Stop] Stop recorded (stop scan from web app)");
                StringAssert.Contains(log.Text, "the logger is not reachable, so nothing is sent now - SCAN 0, LOG_CLR, *RST go out when its link reconnects");
                Assert.IsFalse(log.Text.Contains(StoppedLine));
            }
            Assert.IsTrue(hydra.Host.ScanStopped, "the stop still holds");
            Assert.AreEqual(BaseBLDevice.DeviceSteps.Close, hydra.BL.GetProperty("CurrentStep"));
        }

        [TestMethod]
        public void AStoppedLoggerThatReconnectsIsStoppedForRealAndNotSetUp()
        {
            var hydra = ConnectedHydra();
            StopWhileUnplugged(hydra);
            using (var log = new LogCapture())
            {
                Replug(hydra);

                PumpUntilSent(hydra, "SCAN 0");
                Reply(hydra);
                PumpUntilSent(hydra, "LOG_CLR");
                Reply(hydra);
                PumpUntilSent(hydra, "*RST");
                Reply(hydra);
                Assert.IsTrue(log.WaitFor(StoppedLine), "the stopped line after a connected run");

                // No init and no polling loop: nothing else goes out, however long it is left.
                Pump(hydra);
                CollectionAssert.AreEqual(new[] { "SCAN 0", "LOG_CLR", "*RST" },
                    hydra.Com.SentStrings.Select(s => s.Trim()).ToArray());
                Assert.AreEqual(BaseBLDevice.DeviceSteps.Close, hydra.BL.GetProperty("CurrentStep"));
                Assert.IsTrue(hydra.Host.ScanStopped);
            }
        }

        [TestMethod]
        public void ALinkThatDropsDuringTheStopDoesNotClaimTheLoggerStopped()
        {
            var hydra = ConnectedHydra();
            using (var log = new LogCapture())
            {
                hydra.Host.StopScanning("stop scan from web app");
                PumpUntilSent(hydra, "SCAN 0");

                hydra.Com.IsConnected = false;
                Reply(hydra);

                Assert.IsTrue(log.WaitFor("[HYDRA Stop] The link dropped during the stop sequence (before LOG_CLR); the logger may still be scanning - the stop is sent again when its link reconnects"));
                Pump(hydra);
                Assert.IsFalse(log.Text.Contains(StoppedLine));
            }
        }

        [TestMethod]
        public void AStopSequenceWithAnUnansweredCommandDoesNotClaimTheLoggerStopped()
        {
            var hydra = ConnectedHydra();
            using (var log = new LogCapture())
            {
                hydra.BL.Invoke("SendStopCommand", Hydra2DeviceBL.StopCommands.Length, hydra.Generation, new List<string> { "LOG_CLR" });

                StringAssert.Contains(log.Text, "[HYDRA Stop] The stop sequence went out, but LOG_CLR got no acknowledgement; the logger is not confirmed stopped.");
                Assert.IsFalse(log.Text.Contains(StoppedLine));
            }
        }

        [TestMethod]
        public void AStopSequenceOvertakenByAReInitAtItsLastStepSaysSo()
        {
            var hydra = ConnectedHydra();
            var stale = hydra.Generation - 1;
            using (var log = new LogCapture())
            {
                hydra.BL.Invoke("SendStopCommand", Hydra2DeviceBL.StopCommands.Length, stale, new List<string>());

                StringAssert.Contains(log.Text, "[HYDRA Stop] The stop sequence was overtaken by a re-init");
                Assert.IsFalse(log.Text.Contains(StoppedLine));
            }
        }

        [TestMethod]
        public void AConfirmWhileTheReconnectStopIsRunningReInitsTheLogger()
        {
            var hydra = ConnectedHydra();
            StopWhileUnplugged(hydra);
            Replug(hydra);
            PumpUntilSent(hydra, "SCAN 0");
            var reconnectStop = hydra.Generation;

            // The Confirm's Status:Start, then the tick's re-init (ServerCore.CheckDataTimeouts).
            Assert.IsTrue(hydra.Host.RequestResumeScanning("scan confirmed again after a stop"));
            Assert.IsTrue(hydra.Host.ReinitializeBL(hydra.Host.TakePendingReconfigureReason()));
            Assert.AreEqual(reconnectStop + 1, hydra.Generation, "the re-init retires the reconnect's stop");
            Assert.AreEqual(BaseBLDevice.DeviceSteps.Start, hydra.BL.GetProperty("CurrentStep"));

            var sentBefore = hydra.Com.SentStrings.Count;
            Reply(hydra);
            hydra.BL.Invoke("SendStopCommand", 1, reconnectStop, new List<string>());
            Pump(hydra);

            Assert.IsFalse(hydra.Com.SentStrings.Skip(sentBefore).Any(s => s.Trim() == "LOG_CLR"), "the rest of the stop went out over the init");
            Assert.IsTrue(hydra.Com.SentStrings.Count > sentBefore, "the init did not start");
            Assert.IsFalse(hydra.Host.ScanStopped);
        }
    }
}
