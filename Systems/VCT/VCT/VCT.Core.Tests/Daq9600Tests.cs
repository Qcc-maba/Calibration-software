using System.Collections.Generic;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Core.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// GW Instek DAQ-9600 (MBA-1058). The replies here were CAPTURED from the instrument on 2026-11-26
    /// (GEY150853, fw M1.07_S1.02, two DAQ-901 cards, USBTMC), with five K thermocouples on 101-105 and
    /// 106-111 unwired - not taken from the manual.
    /// </summary>
    [TestClass]
    public class Daq9600Tests
    {
        private const string CapturedIdn = "GWInstek,DAQ-9600,GEY150853,M1.07_S1.02";
        private const string CapturedFiveK = "+2.14422233E+01,+2.17258911E+01,+2.16123355E+01,+2.17270551E+01,+2.16997316E+01\n";
        private const string CapturedWithOpenInput =
            "+2.14431038E+01,+2.16258424E+01,+2.15798799E+01,+2.16476840E+01,+2.16859784E+01,+9.90000000E+37\n";

        private static SensorType Tc(SensorType.ThermocoupleTypes type) => new SensorType
        {
            SensType = SensorType.SensorTypes.TCouple,
            ThermocoupleType = type,
            MeasureType = SensorType.MeasureTypes.TEMP,
        };

        #region identification

        [TestMethod]
        public void Identification_MatchesTheCapturedReply()
        {
            Assert.IsTrue(HardwareDeviceHost.IsGwInstekDaq9600(CapturedIdn));
            Assert.IsTrue(HardwareDeviceHost.IsGwInstekDaq9600("GW-INSTEK,DAQ 9600,GEY150853,1.0"), "spelling variants");
        }

        [TestMethod]
        public void Identification_NeedsVendorAndModel()
        {
            Assert.IsFalse(HardwareDeviceHost.IsGwInstekDaq9600("GWInstek,GDM-8261A,GEX123456,1.00"), "another Instek is not this BL's");
            Assert.IsFalse(HardwareDeviceHost.IsGwInstekDaq9600("KEYSIGHT,DAQ970A,MY123,A.01"), "the model digits alone are not enough");
            Assert.IsFalse(HardwareDeviceHost.IsGwInstekDaq9600("ACME,DAQ-9600,1,1"));
            Assert.IsFalse(HardwareDeviceHost.IsGwInstekDaq9600(null));
            Assert.IsFalse(HardwareDeviceHost.IsGwInstekDaq9600(""));
        }

        [TestMethod]
        public void Settings_ResolveTheDaq9600SnToItsOwnFamily_NotTheVendorWideInstek()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreSame(s.Daq9600, s.ResolveFamilyBySN("DAQ-9600"));
            Assert.AreSame(s.Instek, s.ResolveFamilyBySN("Instek"));
            Assert.IsTrue(HardwareBL_Settings.ChannelMasterFamilies.Contains(Daq9600BL.SETTINGS_FAMILY),
                "the readings are compensated per channel, so the app's sensor association must reach this family");
        }

        [TestMethod]
        public void Settings_DefaultsReportCelsius_AndVoltsForDcVolts()
        {
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreEqual(HardwareBL_Settings.Units_Temperature, s.DefaultUnitsForDeviceSN("DAQ-9600"));
            Assert.AreEqual(HardwareBL_Settings.Units_Voltage,
                HardwareBL_Settings.UnitsForSensor(new SensorType { MeasureType = SensorType.MeasureTypes.VoltageDC }));
        }

        [TestMethod]
        public void Settings_AnEmptyBucketFromAnOldSettingsFileIsFilledFromTheDefaults()
        {
            // An upgraded station's HydraBL_Settings.json predates this family: the bucket is the empty object.
            var empty = new HardwareBL_DeviceType();
            var filled = Daq9600BL.FillMissingFromDefaults(empty);
            CollectionAssert.AreEqual(new List<int> { 1, 2, 3, 4, 5 }, filled.Channels);
            Assert.AreEqual(Daq9600Function.Thermocouple, Daq9600Readings.FunctionFor(filled.Sensor));
            Assert.IsTrue(filled.Interval > 0);
            Assert.IsNotNull(filled.Masters);
        }

        [TestMethod]
        public void Settings_WhatTheOperatorSetIsKept()
        {
            var family = new HardwareBL_DeviceType { Channels = new List<int> { 21 }, Interval = 30, Sensor = Tc(SensorType.ThermocoupleTypes.T) };
            var filled = Daq9600BL.FillMissingFromDefaults(family);
            CollectionAssert.AreEqual(new List<int> { 21 }, filled.Channels);
            Assert.AreEqual(30, filled.Interval);
            Assert.AreEqual(SensorType.ThermocoupleTypes.T, filled.Sensor.ThermocoupleType);
        }

        #endregion

        #region channel numbering

        [TestMethod]
        public void AppChannelsMapToSlotTimesHundredPlusTerminal()
        {
            // measured: probes on terminals 1-5 of the slot-1 card answered on 101-105
            AssertMaps(1, 101);
            AssertMaps(5, 105);
            AssertMaps(20, 120);
            AssertMaps(21, 201);
            AssertMaps(40, 220);
            AssertMaps(41, 301);
            AssertMaps(60, 320);
        }

        private static void AssertMaps(int app, int instrument)
        {
            Assert.IsTrue(Daq9600Readings.TryToInstrumentChannel(app, out var ch));
            Assert.AreEqual(instrument, ch);
            Assert.AreEqual(app, Daq9600Readings.ToAppChannel(instrument), "and back");
        }

        [TestMethod]
        public void ChannelsTheInstrumentCannotHaveAreRefused()
        {
            Assert.IsFalse(Daq9600Readings.TryToInstrumentChannel(0, out _));
            Assert.IsFalse(Daq9600Readings.TryToInstrumentChannel(61, out _));
            Assert.AreEqual(0, Daq9600Readings.ToAppChannel(121), "terminal 21 is a current terminal, not a scanned channel");
            Assert.AreEqual(0, Daq9600Readings.ToAppChannel(401));
        }

        [TestMethod]
        public void ScanOrderIsAscending_AsTheInstrumentReportsIt()
        {
            // measured: ROUT:SCAN (@105,101,109) reads back as (@101,105,109), and READ? answers in that order
            var scan = Daq9600Readings.ScanOrder(new[] { 5, 1, 9, 1 }, Daq9600Function.Thermocouple, out var rejected);
            CollectionAssert.AreEqual(new List<int> { 101, 105, 109 }, scan);
            Assert.AreEqual(0, rejected.Count);
            Assert.AreEqual("(@101,105,109)", Daq9600Readings.ChannelList(scan));
        }

        [TestMethod]
        public void FourWireChannelsMustBeTheFirstTenTerminalsOfACard()
        {
            var scan = Daq9600Readings.ScanOrder(new[] { 1, 10, 11, 21, 35, 70 }, Daq9600Function.Pt100FourWire, out var rejected);
            CollectionAssert.AreEqual(new List<int> { 101, 110, 201 }, scan);
            CollectionAssert.AreEquivalent(new List<int> { 11, 35, 70 }, rejected);
        }

        #endregion

        #region setup commands

        [TestMethod]
        public void ThermocoupleSetup_IsTheSequenceVerifiedOnTheInstrument()
        {
            var commands = Daq9600Readings.SetupCommands(Daq9600Function.Thermocouple, Tc(SensorType.ThermocoupleTypes.K),
                new List<int> { 101, 102, 103, 104, 105 }, HardwareBL_DeviceType.MeasurementRates.FAST);
            CollectionAssert.AreEqual(new List<string>
            {
                "ABOR", "*CLS",
                "CONF:TEMP TC,K,(@101,102,103,104,105)",
                "TEMP:TRAN:TC:CHEC ON,(@101,102,103,104,105)",
                "UNIT:TEMP C,(@101,102,103,104,105)",
                "TEMP:NPLC 1,(@101,102,103,104,105)",
                "FORM:READ:CHAN OFF", "FORM:READ:TIME OFF", "FORM:READ:UNIT OFF", "FORM:READ:ALAR OFF",
                "ROUT:SCAN (@101,102,103,104,105)",
                "TRIG:SOUR IMM", "TRIG:COUN 1",
                "SYST:ERR?",
            }, commands);
        }

        [TestMethod]
        public void ThermocoupleSetup_TurnsOpenInputDetectionOnAfterTheConfigure()
        {
            // Without it an open R thermocouple read 789 degC and an open S 292 degC; a CONF turns it off.
            foreach (var type in new[] { SensorType.ThermocoupleTypes.K, SensorType.ThermocoupleTypes.T, SensorType.ThermocoupleTypes.R, SensorType.ThermocoupleTypes.S })
            {
                var commands = Daq9600Readings.SetupCommands(Daq9600Function.Thermocouple, Tc(type), new List<int> { 110 },
                    HardwareBL_DeviceType.MeasurementRates.FAST);
                var conf = commands.FindIndex(c => c.StartsWith("CONF:TEMP TC," + type + ","));
                var check = commands.IndexOf("TEMP:TRAN:TC:CHEC ON,(@110)");
                Assert.IsTrue(conf >= 0, "configure for " + type);
                Assert.IsTrue(check > conf, "open-input detection after the configure, for " + type);
            }
        }

        [TestMethod]
        public void TriggerCountIsOne_SoEachReadReturns()
        {
            // The old Instek BL set TRIG:COUN INF; with it READ? never returns.
            foreach (var f in new[] { Daq9600Function.Thermocouple, Daq9600Function.Pt100FourWire, Daq9600Function.Pt100TwoWire, Daq9600Function.VoltageDc })
            {
                var commands = Daq9600Readings.SetupCommands(f, Tc(SensorType.ThermocoupleTypes.K), new List<int> { 101 }, HardwareBL_DeviceType.MeasurementRates.FAST);
                CollectionAssert.Contains(commands, "TRIG:COUN 1", f.ToString());
                Assert.IsFalse(commands.Any(c => c.Contains("INF")), f.ToString());
            }
        }

        [TestMethod]
        public void NoSetupCommandDrivesAnOutput()
        {
            // The DAQ-901 cards only switch inputs; the mainframe's alarm and digital outputs are never touched.
            foreach (var f in new[] { Daq9600Function.Thermocouple, Daq9600Function.Pt100FourWire, Daq9600Function.Pt100TwoWire, Daq9600Function.VoltageDc })
            {
                foreach (var c in Daq9600Readings.SetupCommands(f, Tc(SensorType.ThermocoupleTypes.K), new List<int> { 101 }, HardwareBL_DeviceType.MeasurementRates.SLOW))
                {
                    Assert.IsFalse(c.StartsWith("OUTP") || c.StartsWith("DIG") || c.StartsWith("SOUR") || c.StartsWith("ROUT:CLOS"), f + ": " + c);
                }
            }
        }

        [TestMethod]
        public void OtherFunctions_UseTheCommandsCheckedOnTheInstrument()
        {
            var scan = new List<int> { 106 };
            var fres = Daq9600Readings.SetupCommands(Daq9600Function.Pt100FourWire, null, scan, HardwareBL_DeviceType.MeasurementRates.SLOW);
            CollectionAssert.Contains(fres, "CONF:FRES 1e3,(@106)");
            CollectionAssert.Contains(fres, "FRES:NPLC 12,(@106)");

            var res = Daq9600Readings.SetupCommands(Daq9600Function.Pt100TwoWire, null, scan, HardwareBL_DeviceType.MeasurementRates.FAST);
            CollectionAssert.Contains(res, "CONF:RES 1e3,(@106)");
            CollectionAssert.Contains(res, "RES:NPLC 1,(@106)");

            var vdc = Daq9600Readings.SetupCommands(Daq9600Function.VoltageDc, null, scan, HardwareBL_DeviceType.MeasurementRates.FAST);
            CollectionAssert.Contains(vdc, "CONF:VOLT:DC AUTO,(@106)");
            CollectionAssert.Contains(vdc, "VOLT:DC:NPLC 1,(@106)");
            Assert.IsFalse(vdc.Any(c => c.StartsWith("UNIT:TEMP") || c.StartsWith("TEMP:")), "no temperature commands for volts");
        }

        [TestMethod]
        public void NothingIsSetUpWithoutAFunctionOrAChannel()
        {
            Assert.IsNull(Daq9600Readings.SetupCommands(Daq9600Function.Unsupported, null, new List<int> { 101 }, HardwareBL_DeviceType.MeasurementRates.FAST));
            Assert.IsNull(Daq9600Readings.SetupCommands(Daq9600Function.Thermocouple, Tc(SensorType.ThermocoupleTypes.K), new List<int>(), HardwareBL_DeviceType.MeasurementRates.FAST));
        }

        [TestMethod]
        public void FunctionFollowsTheSensor()
        {
            Assert.AreEqual(Daq9600Function.Thermocouple, Daq9600Readings.FunctionFor(Tc(SensorType.ThermocoupleTypes.S)));
            Assert.AreEqual(Daq9600Function.Pt100FourWire, Daq9600Readings.FunctionFor(new SensorType { SensType = SensorType.SensorTypes.FRTD }));
            Assert.AreEqual(Daq9600Function.Pt100TwoWire, Daq9600Readings.FunctionFor(new SensorType { SensType = SensorType.SensorTypes.RTD }));
            Assert.AreEqual(Daq9600Function.VoltageDc, Daq9600Readings.FunctionFor(new SensorType { MeasureType = SensorType.MeasureTypes.VoltageDC }));
            Assert.AreEqual(Daq9600Function.Unsupported, Daq9600Readings.FunctionFor(new SensorType { MeasureType = SensorType.MeasureTypes.Frequency }));
            Assert.AreEqual(Daq9600Function.Unsupported, Daq9600Readings.FunctionFor(null));
        }

        #endregion

        #region replies

        [TestMethod]
        public void CapturedReplyParses_OneValuePerChannel()
        {
            Assert.IsTrue(Daq9600Readings.TryParseReadings(CapturedFiveK, 5, out var values));
            Assert.AreEqual(5, values.Count);
            Assert.AreEqual(21.4422233, values[0], 1e-9);
            Assert.AreEqual(21.6997316, values[4], 1e-9);
        }

        [TestMethod]
        public void OpenInputReadsAsOverload()
        {
            Assert.IsTrue(Daq9600Readings.TryParseReadings(CapturedWithOpenInput, 6, out var values));
            Assert.IsFalse(Daq9600Readings.IsOverload(values[4]));
            Assert.IsTrue(Daq9600Readings.IsOverload(values[5]), "+9.9E37 on the unwired channel");
            Assert.IsFalse(Daq9600Readings.IsOverload(-1.0), "a negative reading is a reading");
            Assert.IsFalse(Daq9600Readings.IsOverload(0.0), "so is zero");
        }

        [TestMethod]
        public void AReplyThatDoesNotMatchTheScanIsRefusedWhole()
        {
            // a partial or mangled reply would put values on the wrong channels
            Assert.IsFalse(Daq9600Readings.TryParseReadings(CapturedFiveK, 6, out var v1));
            Assert.AreEqual(0, v1.Count);
            Assert.IsFalse(Daq9600Readings.TryParseReadings("+2.14E+01,+2.1X7E+01", 2, out var v2), "a corrupted digit");
            Assert.AreEqual(0, v2.Count);
            Assert.IsFalse(Daq9600Readings.TryParseReadings("", 1, out _));
            Assert.IsFalse(Daq9600Readings.TryParseReadings(null, 1, out _));
        }

        [TestMethod]
        public void ErrorQueueReply()
        {
            Assert.IsTrue(Daq9600Readings.IsNoError("+0,\"No error\"\n"));
            Assert.IsFalse(Daq9600Readings.IsNoError("+261,\"Not able to execute while scan initiated\""));
            Assert.IsFalse(Daq9600Readings.IsNoError("-100,\"Command error\""));
            Assert.IsFalse(Daq9600Readings.IsNoError(null));
        }

        #endregion

        #region per-channel compensation

        [TestMethod]
        public void ChannelSensor_IsTheAssociatedOne_ElseTheFileMaster_ElseNone()
        {
            Assert.AreEqual("21-449", ChannelCertificates.SensorFor(3, ChannelMasterMap.Empty, new List<string> { "21-449" }));
            Assert.IsNull(ChannelCertificates.SensorFor(3, ChannelMasterMap.Empty, new List<string>()),
                "no sensor at all: the reading is held back, never sent uncorrected");
            Assert.IsNull(ChannelCertificates.SensorFor(3, null, null));

            // the operator associated 21-675 with channels 1-5: that sensor, not the file's master
            var map = ChannelMasterMap.Empty.With(new[] { 1, 2, 3, 4, 5 }, "21-675", true);
            Assert.AreEqual("21-675", ChannelCertificates.SensorFor(3, map, new List<string> { "21-449" }));
        }

        #endregion
    }
}
