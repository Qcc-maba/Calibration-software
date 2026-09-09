using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Core.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the Meatest M-142 command builders and reply parsing.
    /// <para>
    /// ⚠️ Unlike the 5522A tests, the reply strings here are NOT captured from hardware — they are
    /// the shapes the official manual documents. Re-check them against the instrument the first time
    /// it is connected.
    /// </para>
    /// </summary>
    [TestClass]
    public class MeatestM142Tests
    {
        /// <summary>The manual's own example: 20.5 is returned as this.</summary>
        private const string ManualMeasureReply = "2.050000e+001";

        #region safety - the property that matters most on a source reaching 1000 A

        [TestMethod]
        public void InitSequence_NeverConnectsTheOutput()
        {
            // With the 50-turn coil option this instrument drives 1000 A. OUTP ON must not be
            // reachable from an init: the sequence may only reset, clear, or disconnect the output.
            foreach (var step in MeatestM142Commands.InitSequence)
            {
                var cmd = step.Build().Command.Trim();
                Assert.AreNotEqual("OUTP ON", cmd, "init must never connect the output terminals");
                StringAssert.Matches(cmd,
                    new System.Text.RegularExpressions.Regex(@"^(\*RST|\*CLS|OUTP OFF)$"),
                    "unexpected init command: " + cmd);
            }
        }

        [TestMethod]
        public void InitSequence_EndsWithTheOutputDisconnected()
        {
            var last = MeatestM142Commands.InitSequence[MeatestM142Commands.InitSequence.Length - 1].Build().Command;
            Assert.AreEqual("OUTP OFF", last.Trim(),
                "the disconnected end state should be stated, not left as a side effect of *RST");
        }

        [TestMethod]
        public void OutputOn_IsBuiltButIsolated()
        {
            // It exists - a calibration target needs it - and it is exactly the one command the BL
            // never issues on its own.
            Assert.AreEqual("OUTP ON", MeatestM142Commands.BuildOutputOn().Command);
            Assert.AreEqual("OUTP OFF", MeatestM142Commands.BuildOutputOff().Command);
        }

        [TestMethod]
        public void SettingAValueDoesNotConnectIt()
        {
            // The SOUR commands only select a value; the terminals stay disconnected until OUTP ON.
            foreach (var packet in new[]
            {
                MeatestM142Commands.BuildSetVoltage(10),
                MeatestM142Commands.BuildSetCurrent(1),
                MeatestM142Commands.BuildSetResistance(100),
                MeatestM142Commands.BuildSetCapacitance(1e-6),
                MeatestM142Commands.BuildSetFrequency(50),
            })
            {
                StringAssert.StartsWith(packet.Command, "SOUR:");
                Assert.IsFalse(packet.Command.Contains("OUTP"),
                    "a setpoint command must not carry an output-enable: " + packet.Command);
            }
        }

        #endregion

        #region command builders

        [TestMethod]
        public void SetpointsUseInvariantNumberFormatting()
        {
            // A machine that formats 0.5 as "0,5" under a Hebrew locale sends the calibrator a
            // command it cannot parse - and the failure is a silent no-op, not an error.
            Assert.AreEqual("SOUR:VOLT 0.5", MeatestM142Commands.BuildSetVoltage(0.5).Command);
            Assert.AreEqual("SOUR:FREQ 12.75", MeatestM142Commands.BuildSetFrequency(12.75).Command);
        }

        [TestMethod]
        public void QueriesAreMarkedAsExpectingAReply()
        {
            // A query whose packet is not flagged as such never has its reply read, which stalls the
            // session - the bug that stopped the scope after a single measurement.
            Assert.IsTrue(HydraProtocolHelper.Build_M142_QueryOutput().Wait4Respons);
            Assert.IsTrue(HydraProtocolHelper.Build_M142_QueryMeasureConfig().Wait4Respons);
            Assert.IsTrue(HydraProtocolHelper.Build_M142_Measure().Wait4Respons);
            Assert.IsTrue(HydraProtocolHelper.Build_M142_Identify().Wait4Respons);

            Assert.IsFalse(HydraProtocolHelper.Build_M142_Reset().Wait4Respons);
            Assert.IsFalse(HydraProtocolHelper.Build_M142_OutputOff().Wait4Respons);
        }

        [TestMethod]
        public void SetpointQueryFollowsTheConfiguredMeasureType()
        {
            Assert.AreEqual("SOUR:VOLT?", Query(SensorType.MeasureTypes.VoltageDC));
            Assert.AreEqual("SOUR:CURR?", Query(SensorType.MeasureTypes.Current));
            Assert.AreEqual("SOUR:RES?", Query(SensorType.MeasureTypes.Resistance));
            Assert.AreEqual("SOUR:FREQ?", Query(SensorType.MeasureTypes.Frequency));

            // No configured sensor at all still produces a usable query rather than a null packet.
            Assert.AreEqual("SOUR:VOLT?", HydraProtocolHelper.Build_M142_QuerySetpoint(null).Command);
        }

        private static string Query(SensorType.MeasureTypes measureType)
        {
            return HydraProtocolHelper.Build_M142_QuerySetpoint(
                new SensorType { MeasureType = measureType }).Command;
        }

        #endregion

        #region reply parsing

        [TestMethod]
        public void TryParseValue_ReadsTheManualsExponentialForm()
        {
            double value;
            Assert.IsTrue(MeatestM142Readings.TryParseValue(ManualMeasureReply, out value));
            Assert.AreEqual(20.5, value, 1e-9);
        }

        [TestMethod]
        public void TryParseValue_HandlesFramingAndSigns()
        {
            double value;
            Assert.IsTrue(MeatestM142Readings.TryParseValue("-1.234500e-003\r\n", out value));
            Assert.AreEqual(-0.0012345, value, 1e-12);
        }

        [TestMethod]
        public void TryParseValue_RejectsRatherThanReturningZero()
        {
            // On a calibrator 0 V is a legitimate setpoint, so a parse failure that returned 0 would
            // be indistinguishable from a real reading after the fact.
            double value;
            Assert.IsFalse(MeatestM142Readings.TryParseValue("", out value));
            Assert.IsFalse(MeatestM142Readings.TryParseValue(null, out value));
            Assert.IsFalse(MeatestM142Readings.TryParseValue("OFF", out value));
        }

        [TestMethod]
        public void IsOutputLive_ReadsBothSpellings()
        {
            // OUTP? answers the words, but the command also accepts 0/1 and some firmware echoes it.
            Assert.IsTrue(MeatestM142Readings.IsOutputLive("ON"));
            Assert.IsTrue(MeatestM142Readings.IsOutputLive("ON\r\n"));
            Assert.IsTrue(MeatestM142Readings.IsOutputLive("1"));

            Assert.IsFalse(MeatestM142Readings.IsOutputLive("OFF"));
            Assert.IsFalse(MeatestM142Readings.IsOutputLive("0"));

            // Unreadable must report "not live" - erring towards de-energised.
            Assert.IsFalse(MeatestM142Readings.IsOutputLive(null));
            Assert.IsFalse(MeatestM142Readings.IsOutputLive("???"));
        }

        [TestMethod]
        public void MeterMode_DrivesTheChoiceBetweenMeasurementAndSetpoint()
        {
            Assert.IsTrue(MeatestM142Readings.IsMeterOff("OFF"));
            Assert.IsTrue(MeatestM142Readings.IsMeterOff("off\r\n"));

            // An unreadable reply counts as off, so the BL falls back to the setpoint rather than
            // broadcasting a measurement it cannot vouch for.
            Assert.IsTrue(MeatestM142Readings.IsMeterOff(null));
            Assert.IsTrue(MeatestM142Readings.IsMeterOff(""));

            Assert.IsFalse(MeatestM142Readings.IsMeterOff("VOLT"));
            Assert.IsFalse(MeatestM142Readings.IsMeterOff("TEMPerature:RTD"));
        }

        [TestMethod]
        public void UnitsForMeterMode_CoversEveryDocumentedMode()
        {
            Assert.AreEqual(HardwareBL_Settings.Units_Voltage, MeatestM142Readings.UnitsForMeterMode("VOLT"));
            // Millivolts stay in the Volt vocabulary: the value carries the scale, and a second
            // voltage unit would split one quantity across two names downstream.
            Assert.AreEqual(HardwareBL_Settings.Units_Voltage, MeatestM142Readings.UnitsForMeterMode("MVOLT"));
            Assert.AreEqual(HardwareBL_Settings.Units_Current, MeatestM142Readings.UnitsForMeterMode("CURR"));
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, MeatestM142Readings.UnitsForMeterMode("RES"));
            Assert.AreEqual(HardwareBL_Settings.Units_Frequency, MeatestM142Readings.UnitsForMeterMode("FREQ"));
            Assert.AreEqual(HardwareBL_Settings.Units_Temperature, MeatestM142Readings.UnitsForMeterMode("TEMPerature:RTD"));
            Assert.AreEqual(HardwareBL_Settings.Units_Temperature, MeatestM142Readings.UnitsForMeterMode("TEMPerature:THERmocouple"));
        }

        #endregion

        #region identification

        [TestMethod]
        public void Identification_MatchesTheManualsIdnReply()
        {
            Assert.IsTrue(HardwareDeviceHost.IsMeatestM142("MEATEST,M-142,412341,4.6"));
            // A reply that spaces the model instead of hyphenating it is the same instrument.
            Assert.IsTrue(HardwareDeviceHost.IsMeatestM142("MEATEST,M 142,412341,4.6"));
        }

        [TestMethod]
        public void Identification_DoesNotClaimOtherMeatestModels()
        {
            // The M-140 and M-143 are different instruments with different capabilities; a
            // vendor-only match would hand them to this BL.
            Assert.IsFalse(HardwareDeviceHost.IsMeatestM142("MEATEST,M-140,000001,1.0"));
            Assert.IsFalse(HardwareDeviceHost.IsMeatestM142("MEATEST,M-143,000001,1.0"));
        }

        [TestMethod]
        public void Identification_RequiresTheVendorToo()
        {
            // The model match strips hyphens and spaces, which is loose enough that the vendor name
            // is what keeps an unrelated reply containing those digits from being claimed.
            Assert.IsFalse(HardwareDeviceHost.IsMeatestM142("SOMEVENDOR,M142,1,1"));
            Assert.IsFalse(HardwareDeviceHost.IsMeatestM142(null));
            Assert.IsFalse(HardwareDeviceHost.IsMeatestM142(""));
        }

        [TestMethod]
        public void SettingsResolveTheFamilyFromTheIdentificationSN()
        {
            // The settings lookup and the BLCore token have to agree, or the device is claimed by a
            // BL while being configured by nothing.
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            var family = settings.ResolveFamilyBySN("M-142");

            Assert.IsNotNull(family, "M-142 must resolve to its own settings family");
            Assert.AreSame(settings.MeatestM142, family);
            Assert.AreEqual(HardwareBL_Settings.Units_Voltage, settings.DefaultUnitsForDeviceSN("M-142"),
                "an electrical calibrator must not default to Celsius");
        }

        #endregion
    }
}
