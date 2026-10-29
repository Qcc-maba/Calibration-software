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
        public void TheSameAssociationAgain_ChangesNothing()
        {
            var s = HardwareBL_Settings.Read();
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            Assert.IsNotNull(s.SetWebSocketChannelMasters("21-337", "11", "31-98", replace: false));

            Assert.IsNull(s.SetWebSocketChannelMasters("21-337", "11", "31-98", replace: false));
        }
    }
}
