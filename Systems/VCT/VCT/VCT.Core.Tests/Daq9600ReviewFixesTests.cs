using System;
using System.Collections.Generic;
using ComServerBL.Hydra2.DAL.Calibration;
using Maba.DAL.BaseDAL.Records;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Core.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.CommServer.Core;
using Maba.VCT.CommServer.Core.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>MBA-1058, PR #76 review: one test (or more) per finding.</summary>
    [TestClass]
    public class Daq9600ReviewFixesTests
    {
        private const string Daq9600Core = "Maba.VCT.CommServer.BL.HydraDevices.BLCore.Daq9600BLCore";

        #region finding 1 - an upgraded station's module list gets the new BL core

        [TestMethod]
        public void AnOldModuleListGetsTheDaq9600Core()
        {
            var old = new[]
            {
                new Module { AssemblyName = "Maba.VCT.CommServer.BL.HydraDevices", TypeName = "Maba.VCT.CommServer.BL.HydraDevices.BLCore.Hydra2BLCore" },
            };
            var merged = ComServerSettings.AddMissingModules(old, out var added);
            Assert.AreEqual(2, merged.Length);
            Assert.AreEqual("Maba.VCT.CommServer.BL.HydraDevices.BLCore.Hydra2BLCore", merged[0].TypeName, "the station's own modules stay first, unchanged");
            Assert.AreEqual(Daq9600Core, merged[1].TypeName);
            CollectionAssert.AreEqual(new List<string> { "Daq9600BLCore" }, added);
        }

        [TestMethod]
        public void AModuleAlreadyListedIsNotAddedTwice()
        {
            var current = new[] { new Module { AssemblyName = "Maba.VCT.CommServer.BL.HydraDevices", TypeName = Daq9600Core } };
            var merged = ComServerSettings.AddMissingModules(current, out var added);
            Assert.AreEqual(1, merged.Length);
            Assert.AreEqual(0, added.Count);
        }

        [TestMethod]
        public void AHostWithNoModulesIsLeftAlone()
        {
            Assert.IsNull(ComServerSettings.AddMissingModules(null, out var a1));
            Assert.AreEqual(0, ComServerSettings.AddMissingModules(new Module[0], out var a2).Length);
            Assert.AreEqual(0, a1.Count + a2.Count);
        }

        #endregion

        #region finding 2 - the interval stays below the 60 s data watchdog

        [TestMethod]
        public void IntervalIsCappedBelowTheWatchdog()
        {
            Assert.AreEqual(TimeSpan.FromSeconds(10), Daq9600BL.ClampInterval(10));
            Assert.AreEqual(TimeSpan.FromSeconds(50), Daq9600BL.ClampInterval(50));
            Assert.AreEqual(TimeSpan.FromSeconds(50), Daq9600BL.ClampInterval(60), "60 s would trip the watchdog every sweep");
            Assert.AreEqual(TimeSpan.FromSeconds(50), Daq9600BL.ClampInterval(3600));
            Assert.AreEqual(TimeSpan.FromSeconds(1), Daq9600BL.ClampInterval(0));
            Assert.AreEqual(TimeSpan.FromSeconds(1), Daq9600BL.ClampInterval(-5));
        }

        #endregion

        #region finding 3 - a held-back channel says why, and a settled reason is alerted

        [TestMethod]
        public void OnlyACertificateStillLoadingIsUnsettled()
        {
            Assert.AreEqual(ChannelCertificates.Outcome.Loading, ChannelCertificates.Settle(ChannelCertificates.HoldReason.Certificate, false, false));
            Assert.AreEqual(ChannelCertificates.Outcome.ReadFailed, ChannelCertificates.Settle(ChannelCertificates.HoldReason.Certificate, false, true));
            Assert.AreEqual(ChannelCertificates.Outcome.NoneOnFile, ChannelCertificates.Settle(ChannelCertificates.HoldReason.Certificate, true, false));
            Assert.AreEqual(ChannelCertificates.Outcome.NoSensor, ChannelCertificates.Settle(ChannelCertificates.HoldReason.NoSensor, false, false));
        }

        [TestMethod]
        public void APt100WithoutCoefficientsIsSettledAndNamedForWhatItIs()
        {
            // The case the review found: the correction certificate may well be loaded; the coefficients are not.
            var outcome = ChannelCertificates.Settle(ChannelCertificates.HoldReason.NoCoefficients, noneOnFile: false, readFailed: false);
            Assert.AreEqual(ChannelCertificates.Outcome.NoCoefficients, outcome);
            StringAssert.Contains(ChannelCertificates.LogText(outcome), "ITS-90 coefficients");
            StringAssert.Contains(ChannelCertificates.AlertText(outcome, "21-114"), "21-114");
            Assert.IsFalse(ChannelCertificates.LogText(outcome).Contains("not loaded yet"), "the old, wrong reason");
        }

        [TestMethod]
        public void ARefusalWithTheCertificateLoadedIsSettled()
        {
            Assert.AreEqual(ChannelCertificates.Outcome.ConversionFailed,
                ChannelCertificates.Settle(ChannelCertificates.HoldReason.ConversionFailed, false, false));
        }

        [TestMethod]
        public void EveryReasonIsAlertedOnce()
        {
            var alerts = new List<string>();
            var certs = new ChannelCertificates(null, "TEST", (type, message, channel) => alerts.Add(type + "|" + channel + "|" + message));
            var held = new Dictionary<int, ChannelCertificates.HeldBack>
            {
                [1] = new ChannelCertificates.HeldBack(null, ChannelCertificates.HoldReason.NoSensor),
                [2] = new ChannelCertificates.HeldBack(null, ChannelCertificates.HoldReason.NoSensor),
            };
            certs.ReportHeldBack(held);
            certs.ReportHeldBack(held);
            Assert.AreEqual(2, alerts.Count, "one per channel, and not again on the next sweep");
            StringAssert.StartsWith(alerts[0], "CorrectionUnavailable|1|");
        }

        #endregion

        #region finding 4 - a corrupted READ? reply is an answer, not an exception

        private static LogsResponse ParseRead(string reply)
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            response.ParseLogResponse(new HardwarePacket("READ?", true), new HardwarePacket(reply), LogsRequest.LogCommands.GetLogs);
            return response;
        }

        [TestMethod]
        public void ACorruptedDigitDoesNotThrow()
        {
            var response = ParseRead("+2.14E+01,+2.1X7E+01\n");
            Assert.IsTrue(response.HasResponse, "the request is answered");
            Assert.AreEqual(0, response.Measurements.Count, "all or nothing");
            Assert.AreEqual("+2.14E+01,+2.1X7E+01\n", response.RawText, "the BL still sees the text");
        }

        [TestMethod]
        public void TheDaq9600ReplyStillParses()
        {
            var response = ParseRead("+2.14422233E+01,+2.17258911E+01,+9.90000000E+37\n");
            Assert.AreEqual(3, response.Measurements.Count);
            Assert.AreEqual(21.4422233, response.Measurements[0], 1e-9);
        }

        [TestMethod]
        public void The34401aReplyStillParses()
        {
            // 34401A over RS-232: one value, CRLF-terminated
            var response = ParseRead("+1.08123400E+02\r\n");
            Assert.AreEqual(1, response.Measurements.Count);
            Assert.AreEqual(108.1234, response.Measurements[0], 1e-9);
        }

        #endregion

        #region finding 5 - one BL per unit

        [TestMethod]
        public void TheSerialIsPartOfTheSn()
        {
            Assert.AreEqual("DAQ-9600_GEY150853", HardwareDeviceHost.Daq9600Sn("GWInstek,DAQ-9600,GEY150853,M1.07_S1.02"));
            Assert.AreEqual("DAQ-9600_GEY140708", HardwareDeviceHost.Daq9600Sn("GWInstek,DAQ-9600,GEY 140708,M1.07"), "letters and digits only");
            Assert.AreEqual("DAQ-9600", HardwareDeviceHost.Daq9600Sn("GWInstek,DAQ-9600"), "no serial in the reply");
            Assert.AreNotEqual(HardwareDeviceHost.Daq9600Sn("GWInstek,DAQ-9600,GEY150853,1"),
                               HardwareDeviceHost.Daq9600Sn("GWInstek,DAQ-9600,GEY140706,1"), "two units, two BLs");
        }

        [TestMethod]
        public void TheSnWithASerialStillResolvesToTheFamily()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreSame(s.Daq9600, s.ResolveFamilyBySN("DAQ-9600_GEY150853"));
            Assert.AreEqual(HardwareBL_Settings.Units_Temperature, s.DefaultUnitsForDeviceSN("DAQ-9600_GEY150853"));
        }

        #endregion

        #region finding 6 - an empty bucket runs at the default rate

        [TestMethod]
        public void AnEmptyBucketTakesTheDefaultRate()
        {
            var filled = Daq9600BL.FillMissingFromDefaults(new HardwareBL_DeviceType());
            Assert.AreEqual(HardwareBL_DeviceType.MeasurementRates.FAST, filled.MeasurementRate);
        }

        [TestMethod]
        public void AConfiguredBucketKeepsItsSlowRate()
        {
            var family = new HardwareBL_DeviceType
            {
                Channels = new List<int> { 1 },
                MeasurementRate = HardwareBL_DeviceType.MeasurementRates.SLOW,
            };
            Assert.AreEqual(HardwareBL_DeviceType.MeasurementRates.SLOW, Daq9600BL.FillMissingFromDefaults(family).MeasurementRate);
        }

        #endregion

        #region finding 7 - a timeout is recognised

        [TestMethod]
        public void ATimeoutIsRecognisedByTheSessionsMessage()
        {
            Assert.IsTrue(Daq9600BL.TimedOut(new LogsResponse(false, LogsRequest.LogCommands.GetLogs) { Message = "Request was timed-out!" }));
            Assert.IsTrue(Daq9600BL.TimedOut(new InitSystemResponse(false) { Message = "Request was timed-out!" }));
            Assert.IsFalse(Daq9600BL.TimedOut(new LogsResponse(false, LogsRequest.LogCommands.GetLogs)));
            Assert.IsFalse(Daq9600BL.TimedOut(new LogsResponse(true, LogsRequest.LogCommands.GetLogs)));
            Assert.IsFalse(Daq9600BL.TimedOut(null));
        }

        #endregion

        #region re-check at b9277cf - per-channel alerts, PT-100 reasons, a log tag per unit

        [TestMethod]
        public void ASecondChannelOfTheSameSensorIsAlertedToo()
        {
            var alerts = new List<string>();
            var certs = new ChannelCertificates(null, "TEST", (type, message, channel) => alerts.Add(channel));
            var refused = ChannelCertificates.HoldReason.ConversionFailed;

            certs.ReportHeldBack(new Dictionary<int, ChannelCertificates.HeldBack> { [1] = new ChannelCertificates.HeldBack("21-675", refused) });
            certs.ReportHeldBack(new Dictionary<int, ChannelCertificates.HeldBack>
            {
                [1] = new ChannelCertificates.HeldBack("21-675", refused),
                [3] = new ChannelCertificates.HeldBack("21-675", refused),
            });
            CollectionAssert.AreEqual(new List<string> { "1", "3" }, alerts, "CH3 is alerted when it joins; CH1 is not alerted again");

            certs.ReportHeldBack(new Dictionary<int, ChannelCertificates.HeldBack> { [3] = new ChannelCertificates.HeldBack("21-675", refused) });
            Assert.AreEqual(2, alerts.Count, "not again on the next sweep");
        }

        [TestMethod]
        public void APt100WrongValueIsNamedByWhetherTheCoefficientsExist()
        {
            Assert.AreEqual(ChannelCertificates.HoldReason.NoCoefficients, Daq9600BL.PtWrongValueReason(false));
            Assert.AreEqual(ChannelCertificates.HoldReason.ConversionFailed, Daq9600BL.PtWrongValueReason(true));
        }

        [TestMethod]
        public void CoefficientsThatCannotConvertAreNotReportedAsMissing()
        {
            var repository = new CalibrationRepository();
            repository.SetSensorCoefficients("21-114", new SensorCoefficients(0, 0, 0, 0, 0, 0)); // RTP 0: every value is WrongValue
            var hc = new HydraCalculations(repository);

            Assert.AreEqual(CalibrationRepository.ResultStatus.WrongValue, hc.CalcResistanceToTemperatureITS90("21-114", 100).Item2);
            Assert.IsTrue(hc.HasSensorCoefficients("21-114"));
            Assert.AreEqual(ChannelCertificates.HoldReason.ConversionFailed, Daq9600BL.PtWrongValueReason(hc.HasSensorCoefficients("21-114")));
            Assert.IsFalse(hc.HasSensorCoefficients("21-999"));
            Assert.IsFalse(hc.HasSensorCoefficients(null));
        }

        [TestMethod]
        public void EachUnitLogsUnderItsOwnSn()
        {
            Assert.AreEqual("DAQ-9600_GEY150853", Daq9600BL.LogTagFor("DAQ-9600_GEY150853"));
            Assert.AreNotEqual(Daq9600BL.LogTagFor("DAQ-9600_GEY150853"), Daq9600BL.LogTagFor("DAQ-9600_GEY140706"));
            Assert.AreEqual("DAQ-9600", Daq9600BL.LogTagFor(null));
            Assert.AreEqual("DAQ-9600", Daq9600BL.LogTagFor("  "));
        }

        #endregion
    }
}
