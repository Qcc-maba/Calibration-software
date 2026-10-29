using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using ComServerBL.Hydra2.DAL.Calibration;
using Maba.DAL.BaseDAL.Records;
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
    /// MBA-1007 - each Hydra 2625A channel is compensated with the sensor the operator associated with it.
    /// <para>
    /// Before: every reading was compensated with the first master in HydraBL_Settings.json. On the bench
    /// on 2026-10-28 sensor 31-98 was chosen on channels 11-13 and all 21 readings were compensated with
    /// 21-449: 22.1 became 22.0701 instead of 22.2336.
    /// </para>
    /// Driven end to end like the MBA-967 tests: the real Hydra2 BL on a Fluke identified on the server's
    /// bus, the app's Confirm through the socket, and the LoggerData lines read back off the client.
    /// The certificates are the real ones' two points around room temperature.
    /// </summary>
    [TestClass]
    public class Hydra2CompensationSensorTests
    {
        private const string Logger = "21-337";
        private const double Tolerance = 1e-6;
        private static readonly Regex ChannelValue = new Regex("Channel:\"(\\d+)\", Value:\"([^\"]+)\"");

        /// <summary>21-449, CorVersion 12: +0.22 at 0.03 degC, -0.10 at 37.19 degC.</summary>
        private static readonly List<CorrectionValues> Certificate21_449 = Points((0.03, 0.22), (37.19, -0.10));

        /// <summary>31-98, CorVersion 1: -0.08 at 0.031 degC, -0.170001 at 37.074 degC.</summary>
        private static readonly List<CorrectionValues> Certificate31_98 = Points((0.031, -0.08), (37.074, -0.170001));

        /// <summary>A flat +0.5 certificate, so its readings are told apart at a glance.</summary>
        private static readonly List<CorrectionValues> Certificate21_675 = Points((0.0, 0.5), (50.0, 0.5));

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
            public MockComLayer Client;
            public PrivateObject BL;
            public CalibrationRepository Certificates;
        }

        /// <summary>The Fluke identified and driven by its Hydra2 BL, with 21-449 (the file's master) on file.</summary>
        private static Bench IdentifiedBench()
        {
            var b = new Bench { Server = new ServerCore() };

            var link = new MockComLayer();
            b.Fluke = new HardwareDeviceHost(b.Server.MainEventsBus, link, new DeviceSettings());
            b.Fluke.InitSessions();
            var idn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            link.SimulateDataReceived(idn, 0, idn.Length);

            var blCore = new Hydra2BLCore();
            blCore.Start(b.Server);
            Assert.IsTrue(blCore.OnDeviceConnetion(b.Fluke), "test setup: the Hydra2 BL did not claim the Fluke");
            b.BL = new PrivateObject(b.Fluke.BL);

            // The BL's own repository; its connection string points nowhere (app.config), so a certificate
            // is on file only when a test puts it here.
            var hc = new PrivateObject(b.BL.GetField("HC"));
            b.Certificates = (CalibrationRepository)hc.GetField("_repository");
            b.Certificates.SetCorrectionValues("21-449", Certificate21_449);

            b.Client = new MockComLayer();
            b.Server.RegisterWebSocketClient("WS", new WebSocketDeviceHost(new EventsBus(), b.Client, "WS"));
            return b;
        }

        /// <summary>The logger dialog's Confirm: the full list, then one association per sensor.</summary>
        private static void Confirm(MockComLayer client, string channels, params (string Sensor, string Channels)[] sensors)
        {
            client.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"" + Logger + "\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"" + channels + "\", DeviceID:\"0\"");
            foreach (var s in sensors)
            {
                Associate(client, s.Sensor, s.Channels);
            }
        }

        private static void Associate(MockComLayer client, string sensor, string channels)
        {
            client.SimulateStringDataReceived("CMD:\"SensorsAssociation\", LoggerID:\"" + Logger + "\", DeviceID:\"" + sensor + "\", BatchID:\"" + sensor
                + "\", BatchChannels:\"" + channels + "\", Units:\"Celsius\", Resolution:\"2\", SendData:\"true\"");
        }

        /// <summary>One logged scan, a value per scanned channel in the scan list's order. No scan time, so none is skipped as already sent.</summary>
        private static void Scan(Bench b, params double[] values)
        {
            var entry = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            entry.Measurements.AddRange(values);
            b.BL.Invoke("BroadcastEntry", entry);
        }

        /// <summary>The value of each channel in the LoggerData lines sent since the last call - the last scan.</summary>
        private static Dictionary<int, double> LastScan(MockComLayer client)
        {
            var result = new Dictionary<int, double>();
            while (client.SentStrings.TryDequeue(out var line))
            {
                if (!line.StartsWith("CMD:\"LoggerData\"", StringComparison.Ordinal)) continue;
                foreach (Match m in ChannelValue.Matches(line))
                {
                    result[int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture)] =
                        double.Parse(m.Groups[2].Value, CultureInfo.InvariantCulture);
                }
            }
            return result;
        }

        private static readonly Regex AlertLine = new Regex(
            "^CMD:\"Alert\", DeviceID:\"([^\"]*)\".*Channel:\"([^\"]*)\".*AlertType:\"([^\"]*)\", Message:\"([^\"]*)\"");

        /// <summary>The alerts of one type sent since the last call (it reads everything sent, LoggerData included).</summary>
        private static List<(string DeviceId, string Channel, string Message)> SentAlerts(MockComLayer client, string alertType)
        {
            var result = new List<(string DeviceId, string Channel, string Message)>();
            while (client.SentStrings.TryDequeue(out var line))
            {
                var m = AlertLine.Match(line);
                if (m.Success && m.Groups[3].Value == alertType)
                {
                    result.Add((m.Groups[1].Value, m.Groups[2].Value, m.Groups[4].Value));
                }
            }
            return result;
        }

        private static List<CorrectionValues> Points(params (double Temperature, double Deviation)[] points)
        {
            return points.Select(p => new CorrectionValues { TemperatureValue = p.Temperature, Deviation = p.Deviation }).ToList();
        }

        #endregion

        #region the chosen sensor compensates

        [TestMethod]
        public void TheBenchRun_IsCompensatedWith31_98_Not21_449()
        {
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            Confirm(b.Client, "11,12,13", ("31-98", "11,12,13"));

            Scan(b, 22.1, 22.1, 22.2);

            var scan = LastScan(b.Client);
            Assert.AreEqual(22.233620, scan[11], Tolerance, "CH11: 22.1 with 31-98's certificate (21-449 gave 22.0701)");
            Assert.AreEqual(22.233620, scan[12], Tolerance);
            Assert.AreEqual(22.333863, scan[13], Tolerance, "CH13: 22.2 with 31-98's certificate (21-449 gave 22.1709)");
        }

        [TestMethod]
        public void TwoSensorsOnOneLogger_EachIsCompensatedWithItsOwnCertificate()
        {
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            b.Certificates.SetCorrectionValues("21-675", Certificate21_675);
            Confirm(b.Client, "1,2,14", ("21-675", "1,2"), ("31-98", "14"));

            Scan(b, 22.1, 22.1, 22.1);

            var scan = LastScan(b.Client);
            Assert.AreEqual(21.6, scan[1], Tolerance, "CH1 is 21-675's");
            Assert.AreEqual(21.6, scan[2], Tolerance, "CH2 is 21-675's");
            Assert.AreEqual(22.233620, scan[14], Tolerance, "CH14 is 31-98's");
        }

        [TestMethod]
        public void AnotherSensorOnTheSameChannels_SwitchesTheCompensation()
        {
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            b.Certificates.SetCorrectionValues("21-675", Certificate21_675);
            Confirm(b.Client, "11", ("31-98", "11"));
            Scan(b, 22.1);
            Assert.AreEqual(22.233620, LastScan(b.Client)[11], Tolerance, "test setup: 31-98 first");

            Confirm(b.Client, "11", ("21-675", "11"));
            Scan(b, 22.1);

            Assert.AreEqual(21.6, LastScan(b.Client)[11], Tolerance, "the new sensor's certificate, not the first one's");
        }

        [TestMethod]
        public void TheAppResendingLoggerConfigurationMidRun_KeepsTheSensor()
        {
            // The graph screen re-sends LoggerConfiguration and then the associations (15:23:22 on the
            // bench). A scan landing between the two must not fall back to the file's master.
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            Confirm(b.Client, "11", ("31-98", "11"));

            b.Client.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"" + Logger + "\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"11\", DeviceID:\"0\"");
            Scan(b, 22.1);

            Assert.AreEqual(22.233620, LastScan(b.Client)[11], Tolerance);
        }

        [TestMethod]
        public void ASensorAssociatedMidRun_IsLoadedAtItsFirstReading()
        {
            // No re-init: the channels did not change, only the sensor on them. Its certificate is not in
            // the cache until its first reading looks it up.
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            Confirm(b.Client, "11", ("31-98", "11"));
            Scan(b, 22.1);
            LastScan(b.Client);

            Associate(b.Client, "21-675", "11");
            b.Certificates.SetCorrectionValues("21-675", Certificate21_675);
            Scan(b, 22.1);

            Assert.AreEqual(21.6, LastScan(b.Client)[11], Tolerance);
        }

        #endregion

        #region no certificate, and no association

        [TestMethod]
        public void ASensorWithNoCertificate_IsNotSent_AndNotCompensatedWithAnotherOne()
        {
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            Confirm(b.Client, "1,14", ("99-999", "1"), ("31-98", "14"));

            Scan(b, 22.1, 22.1);

            var scan = LastScan(b.Client);
            Assert.IsFalse(scan.ContainsKey(1), "CH1's sensor has no certificate: nothing is sent for it");
            Assert.AreEqual(22.233620, scan[14], Tolerance, "the other sensor's channel still goes out");
        }

        [TestMethod]
        public void ASensorWithNoCertificate_StillTellsTheWatchdogTheLoggerIsScanning()
        {
            var b = IdentifiedBench();
            Confirm(b.Client, "1", ("99-999", "1"));
            new PrivateObject(b.Fluke).SetProperty("LastMeasurementUtc", (DateTime?)null);

            Scan(b, 22.1);

            Assert.IsTrue(b.Fluke.LastMeasurementUtc.HasValue,
                "a scan with every reading held back is still a scan - the data watchdog must not reset a working logger");
        }

        [TestMethod]
        public void ANewConfirmThatLeavesAChannelUnnamed_CompensatesItWithTheSensorItIsLabelledWith()
        {
            // Review of #41: run 1 had 31-98 on 11-14; run 2 associated 21-675 with 11-13 only. Channel 14's
            // label was cleared, so it went out as 21-675 - and was corrected with 31-98's certificate.
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            b.Certificates.SetCorrectionValues("21-675", Certificate21_675);
            Confirm(b.Client, "11,12,13,14", ("31-98", "11,12,13,14"));
            Scan(b, 22.1, 22.1, 22.1, 22.1);
            Assert.AreEqual(22.233620, LastScan(b.Client)[14], Tolerance, "test setup: 31-98 first");

            Confirm(b.Client, "11,12,13,14", ("21-675", "11,12,13"));
            Scan(b, 22.1, 22.1, 22.1, 22.1);

            Assert.AreEqual(21.6, LastScan(b.Client)[14], Tolerance, "channel 14 is labelled 21-675 now, so it is corrected as 21-675");
        }

        [TestMethod]
        public void NoCertificateOnFile_IsNotAskedAgainOnEveryScan()
        {
            var b = IdentifiedBench();
            Confirm(b.Client, "1", ("99-999", "1"));
            WaitForBackgroundLoads(b);
            b.Certificates.SetNoCorrectionsOnFile("99-999");   // what the database answered

            Scan(b, 22.1);
            Scan(b, 22.1);

            Assert.IsFalse(LastScan(b.Client).ContainsKey(1));
            Assert.AreEqual(0, ((HashSet<string>)b.BL.GetField("_certificatesLoading")).Count,
                "the database already answered: nothing to load");
        }

        [TestMethod]
        public void AFailedCertificateRead_IsRetried_NotTakenForNoCertificate()
        {
            // Review of #41: one DB timeout during Confirm used to drop the sensor's channels for the whole
            // run. The test's connection string points nowhere, so every read here fails.
            var b = IdentifiedBench();
            Confirm(b.Client, "1", ("99-999", "1"));

            Scan(b, 22.1);
            WaitForBackgroundLoads(b);
            var retry = (Dictionary<string, DateTime>)b.BL.GetField("_certificateRetryUtc");
            Assert.IsTrue(retry.ContainsKey("99-999"), "a failed read is scheduled again");
            Assert.IsFalse(b.Certificates.IsKnownToHaveNoCorrections("99-999"), "a failed read is not an answer");

            Scan(b, 22.1);
            Assert.AreEqual(0, ((HashSet<string>)b.BL.GetField("_certificatesLoading")).Count, "not again before the retry interval");

            // The retry is due: the next scan reads again, fails again, and is scheduled again.
            var lockObject = b.BL.GetField("_certificateLock");
            lock (lockObject) { retry["99-999"] = DateTime.UtcNow.AddSeconds(-1); }
            Scan(b, 22.1);
            WaitForBackgroundLoads(b);
            lock (lockObject)
            {
                Assert.IsTrue(retry["99-999"] > DateTime.UtcNow, "read again once due, and rescheduled after failing");
            }
            Assert.IsFalse(LastScan(b.Client).ContainsKey(1), "still nothing to compensate with, so still not sent");
        }

        [TestMethod]
        public void ASensorWithNoCertificateOnFile_IsAlertedOnce_OnEachOfItsChannels()
        {
            // MBA-1008: the held-back channels were only in the server log; the operator saw nothing.
            var b = IdentifiedBench();
            b.Certificates.SetCorrectionValues("31-98", Certificate31_98);
            Confirm(b.Client, "1,2,14", ("99-999", "1,2"), ("31-98", "14"));
            WaitForBackgroundLoads(b);
            b.Certificates.SetNoCorrectionsOnFile("99-999");

            Scan(b, 22.1, 22.1, 22.1);
            Scan(b, 22.1, 22.1, 22.1);

            var alerts = SentAlerts(b.Client, "CorrectionUnavailable");
            CollectionAssert.AreEquivalent(new[] { "1", "2" }, alerts.Select(a => a.Channel).ToList(),
                "one alert per held-back channel, not one per scan - and none for 31-98's channel");
            Assert.IsTrue(alerts.All(a => a.DeviceId == "99-999"), "each names the sensor, as that channel's LoggerData would");
            Assert.IsTrue(alerts.All(a => a.Message.Contains("no correction certificate on file")), alerts[0].Message);
        }

        [TestMethod]
        public void AFailedCertificateRead_IsAlertedOnce_AndAgainAfterTheNextAssociation()
        {
            var b = IdentifiedBench();
            Confirm(b.Client, "1", ("99-999", "1"));
            WaitForBackgroundLoads(b);   // the read fails: the test's connection string points nowhere

            Scan(b, 22.1);
            var lockObject = b.BL.GetField("_certificateLock");
            var retry = (Dictionary<string, DateTime>)b.BL.GetField("_certificateRetryUtc");
            lock (lockObject) { retry["99-999"] = DateTime.UtcNow.AddSeconds(-1); }
            Scan(b, 22.1);   // retried, failing again: not alerted a second time
            WaitForBackgroundLoads(b);
            Scan(b, 22.1);

            var first = SentAlerts(b.Client, "CorrectionUnavailable");
            Assert.AreEqual(1, first.Count, "alerted once, however many retries fail");
            StringAssert.Contains(first[0].Message, "could not be read");

            Confirm(b.Client, "1", ("99-999", "1"));   // the operator confirms again: asked afresh, and told afresh
            WaitForBackgroundLoads(b);
            Scan(b, 22.1);

            Assert.AreEqual(1, SentAlerts(b.Client, "CorrectionUnavailable").Count);
        }

        [TestMethod]
        public void AssociatingASensor_StartsLoadingItsCertificateBeforeAnyScan()
        {
            // Re-review of #41 / bench 11:06:24: a sensor switched in mid-run was only looked up by the next
            // scan, which therefore went out without its channels.
            var b = IdentifiedBench();

            Confirm(b.Client, "1", ("99-999", "1"));
            WaitForBackgroundLoads(b);

            var retry = (Dictionary<string, DateTime>)b.BL.GetField("_certificateRetryUtc");
            lock (b.BL.GetField("_certificateLock"))
            {
                Assert.IsTrue(retry.ContainsKey("99-999"), "a load was attempted on the association itself, with no scan at all");
            }
        }

        [TestMethod]
        public void ConfirmingAgain_AsksAgainAboutASensorThatHadNoCertificate()
        {
            // Re-review of #41: a "none on file" answer was never asked again on a Confirm with the same
            // setup (no re-init), so a certificate saved later stayed unused until the service restarted -
            // while the log told the operator that confirming again was enough.
            var b = IdentifiedBench();
            Confirm(b.Client, "1", ("99-999", "1"));
            WaitForBackgroundLoads(b);
            b.Certificates.SetNoCorrectionsOnFile("99-999");
            Scan(b, 22.1);
            Assert.IsFalse(LastScan(b.Client).ContainsKey(1), "test setup: held back, none on file");

            Confirm(b.Client, "1", ("99-999", "1"));

            Assert.IsFalse(b.Certificates.IsKnownToHaveNoCorrections("99-999"), "the new Confirm asks again");
            WaitForBackgroundLoads(b);
            b.Certificates.SetCorrectionValues("99-999", Certificate21_675);   // saved meanwhile, and found
            Scan(b, 22.1);
            Assert.AreEqual(21.6, LastScan(b.Client)[1], Tolerance);
        }

        private static void WaitForBackgroundLoads(Bench b)
        {
            var loading = (HashSet<string>)b.BL.GetField("_certificatesLoading");
            var lockObject = b.BL.GetField("_certificateLock");
            var deadline = DateTime.UtcNow.AddSeconds(60);
            while (DateTime.UtcNow < deadline)
            {
                lock (lockObject) { if (loading.Count == 0) return; }
                System.Threading.Thread.Sleep(20);
            }
            Assert.Fail("test setup: the background certificate load did not finish");
        }

        [TestMethod]
        public void AnAppThatNeverAssociatesASensor_GetsTheFilesMaster_AsBefore()
        {
            var b = IdentifiedBench();
            b.Client.SimulateStringDataReceived("CMD:\"LoggerConfiguration\", LoggerID:\"" + Logger + "\", Rate:\"slow\", Interval:\"30\", BatchChannels:\"11\", DeviceID:\"0\"");

            Scan(b, 22.1);

            Assert.AreEqual(22.070054, LastScan(b.Client)[11], Tolerance, "21-449, the file's master - today's bench value 22.0701");
        }

        #endregion
    }

    /// <summary>MBA-1007 - the sensor of each channel in the settings: added, replaced and held like the channel list.</summary>
    [TestClass]
    public class ChannelMasterSettingsTests
    {
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

        [TestMethod]
        public void AddedAssociations_KeepEachOthersChannels()
        {
            var s = HardwareBL_Settings.Read();
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");

            s.SetWebSocketChannelMasters("21-337", "1,2", "21-675", replace: false);
            s.SetWebSocketChannelMasters("21-337", "14", "31-98", replace: false);

            var map = s.Hydra2type.ChannelMasters;
            Assert.AreEqual("21-675", map.MasterFor(1));
            Assert.AreEqual("21-675", map.MasterFor(2));
            Assert.AreEqual("31-98", map.MasterFor(14));
            Assert.AreEqual("31-98", map.MasterFor(20), "a channel no association named: the last association's sensor, as its label");
        }

        [TestMethod]
        public void AReplacingAssociation_DropsTheOtherChannels()
        {
            var s = HardwareBL_Settings.Read();
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            s.SetWebSocketChannelMasters("21-337", "1,2", "21-675", replace: false);

            s.SetWebSocketChannelMasters("21-337", "14", "31-98", replace: true);

            var map = s.Hydra2type.ChannelMasters;
            CollectionAssert.AreEquivalent(new[] { 14 }, map.ByChannel.Keys.ToArray());
        }

        [TestMethod]
        public void BeforeTheLoggerIsIdentified_TheSensorIsHeld_AndAppliedWithTheChannels()
        {
            // The first Confirm: LoggerConfiguration, SensorsAssociation, Start - all before identification.
            var s = HardwareBL_Settings.Read();
            Assert.IsNull(s.ApplyWebSocketConfig("21-337", "slow", "30", "11,12,13"), "test setup: nothing live, so held");
            Assert.IsNull(s.SetWebSocketChannelMasters("21-337", "11,12,13", "31-98", replace: false));
            Assert.IsTrue(s.Hydra2type.ChannelMasters.IsEmpty, "nothing applied until a logger is identified");

            var summary = s.ApplyPendingWebSocketConfig("Hydra2", DateTime.UtcNow);

            StringAssert.Contains(summary, "compensation 11,12,13=31-98");
            CollectionAssert.AreEqual(new[] { 11, 12, 13 }, s.Hydra2type.Channels.ToArray());
            Assert.AreEqual("31-98", s.Hydra2type.ChannelMasters.MasterFor(11));
        }

        [TestMethod]
        public void TheSensorIsNeverWrittenToTheSettingsFile()
        {
            // HardwareBL_Settings is saved with Newtonsoft; an operator's choice must not become the
            // station's master on the next start.
            var attributes = typeof(HardwareBL_DeviceType).GetProperty(nameof(HardwareBL_DeviceType.ChannelMasters)).GetCustomAttributes(true);

            Assert.IsTrue(attributes.Any(a => a.GetType().Name == "JsonIgnoreAttribute"));
        }

        [TestMethod]
        public void ALoggerConfiguration_ForgetsTheChannels_ButKeepsTheLastSensor()
        {
            var s = HardwareBL_Settings.Read();
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            s.SetWebSocketChannelMasters("21-337", "1,2", "21-675", replace: false);
            s.SetWebSocketChannelMasters("21-337", "14", "31-98", replace: false);

            StringAssert.Contains(s.ClearWebSocketChannelMasters("21-337"), "31-98");

            var map = s.Hydra2type.ChannelMasters;
            Assert.AreEqual(0, map.ByChannel.Count);
            Assert.AreEqual("31-98", map.MasterFor(1), "until the associations follow, every channel is the last sensor's - as its label");
            Assert.IsNull(s.ClearWebSocketChannelMasters("21-337"), "nothing left to clear");
        }

        [TestMethod]
        public void AFamilyThatCompensatesWithItsFileMaster_RecordsNoSensor()
        {
            // Agilent34401aBL still compensates with Masters[0]; recording 31-98 for it would put a sensor in
            // the log that no reading is corrected with.
            var s = HardwareBL_Settings.Read();
            HardwareBL_Settings.RegisterActiveFamily("Agilent");

            Assert.IsNull(s.SetWebSocketChannelMasters("21-337", "1", "31-98", replace: false));

            Assert.IsTrue(s.Agilent.ChannelMasters.IsEmpty);
            Assert.IsFalse(HardwareBL_Settings.IsWebSocketConfigHeld("21-337"), "routed to a live family, so not held either");
        }

        [TestMethod]
        public void TheSameAssociationAgain_ChangesNothing()
        {
            var s = HardwareBL_Settings.Read();
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            Assert.IsNotNull(s.SetWebSocketChannelMasters("21-337", "11", "31-98", replace: false));

            Assert.IsNull(s.SetWebSocketChannelMasters("21-337", "11", "31-98", replace: false));
        }
    }
}
