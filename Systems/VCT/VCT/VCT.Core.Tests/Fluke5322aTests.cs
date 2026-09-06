using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Core.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the Fluke 5322A command builders and reply parsing.
    /// <para>
    /// ⚠️ Unlike the 5522A tests, the reply strings here are NOT captured from hardware — they are
    /// the shapes the Operators Manual documents. Re-check them against the instrument the first
    /// time it is connected. Note also that the 5322A and the 5522A are DIFFERENT instruments: one
    /// is an electrical-safety tester calibrator, the other a multi-product calibrator.
    /// </para>
    /// </summary>
    [TestClass]
    public class Fluke5322aTests
    {
        /// <summary>The manual's own example: 50.54 mOhm is returned as this.</summary>
        private const string ManualSetpointReply = "50.54e-03";

        #region safety - the property that matters most on a hipot source

        [TestMethod]
        public void InitSequence_NeverEnergisesTheOutput()
        {
            // This calibrator sources hipot and flash-test levels. OUTP ON must not be reachable
            // from an init: the sequence may only take remote control, reset, clear, or switch the
            // output off.
            foreach (var step in Fluke5322aCommands.InitSequence)
            {
                var cmd = step.Build().Command.Trim();
                Assert.AreNotEqual("OUTP ON", cmd, "init must never energise the output");
                StringAssert.Matches(cmd,
                    new System.Text.RegularExpressions.Regex(@"^(SYST:REM|\*RST|\*CLS|OUTP OFF)$"),
                    "unexpected init command: " + cmd);
            }
        }

        [TestMethod]
        public void InitSequence_TakesRemoteControlFirst()
        {
            // Over USB the instrument ignores everything until it is in remote mode, so a *RST sent
            // before SYST:REM is silently dropped and the init only appears to have run.
            var first = Fluke5322aCommands.InitSequence[0].Build().Command;
            Assert.AreEqual("SYST:REM", first.Trim());
        }

        [TestMethod]
        public void InitSequence_EndsWithTheOutputOff()
        {
            var last = Fluke5322aCommands.InitSequence[Fluke5322aCommands.InitSequence.Length - 1].Build().Command;
            Assert.AreEqual("OUTP OFF", last.Trim(),
                "the de-energised end state should be stated, not left as a side effect of *RST");
        }

        [TestMethod]
        public void OutputOn_IsBuiltButIsolated()
        {
            // It exists - a calibration target needs it - and it is exactly the one command the BL
            // never issues on its own.
            Assert.AreEqual("OUTP ON", Fluke5322aCommands.BuildOutputOn().Command);
            Assert.AreEqual("OUTP OFF", Fluke5322aCommands.BuildOutputOff().Command);
        }

        [TestMethod]
        public void SettingAValueDoesNotEnergiseIt()
        {
            // SAF:GBR only selects the resistance; the output stays off until OUTP ON.
            var cmd = Fluke5322aCommands.BuildSetGroundBond(0.1).Command;
            Assert.AreEqual("SAF:GBR 0.1", cmd);
            Assert.IsFalse(cmd.Contains("OUTP"));
        }

        #endregion

        #region command builders

        [TestMethod]
        public void SetpointsUseInvariantNumberFormatting()
        {
            // A machine that formats 0.1 as "0,1" under a Hebrew locale sends the calibrator a
            // command it cannot parse - and the failure is a silent no-op, not an error.
            Assert.AreEqual("SAF:GBR 0.025", Fluke5322aCommands.BuildSetGroundBond(0.025).Command);
        }

        [TestMethod]
        public void QueriesAreMarkedAsExpectingAReply()
        {
            // A query whose packet is not flagged as such never has its reply read, which stalls the
            // session - the bug that stopped the scope after a single measurement.
            Assert.IsTrue(HydraProtocolHelper.Build_F5322a_QueryOutput().Wait4Respons);
            Assert.IsTrue(HydraProtocolHelper.Build_F5322a_QueryMode().Wait4Respons);
            Assert.IsTrue(HydraProtocolHelper.Build_F5322a_QueryGroundBond().Wait4Respons);
            Assert.IsTrue(HydraProtocolHelper.Build_F5322a_Identify().Wait4Respons);

            Assert.IsFalse(HydraProtocolHelper.Build_F5322a_Reset().Wait4Respons);
            Assert.IsFalse(HydraProtocolHelper.Build_F5322a_Remote().Wait4Respons);
            Assert.IsFalse(HydraProtocolHelper.Build_F5322a_OutputOff().Wait4Respons);
        }

        #endregion

        #region reply parsing

        [TestMethod]
        public void TryParseValue_ReadsTheManualsExponentialForm()
        {
            double value;
            Assert.IsTrue(Fluke5322aReadings.TryParseValue(ManualSetpointReply, out value));
            Assert.AreEqual(0.05054, value, 1e-9);
        }

        [TestMethod]
        public void TryParseValue_RejectsRatherThanReturningZero()
        {
            // On a calibrator 0 is a legitimate setpoint, so a parse failure that returned 0 would
            // be indistinguishable from a real reading after the fact.
            double value;
            Assert.IsFalse(Fluke5322aReadings.TryParseValue("", out value));
            Assert.IsFalse(Fluke5322aReadings.TryParseValue(null, out value));
            Assert.IsFalse(Fluke5322aReadings.TryParseValue("GBR", out value));
        }

        [TestMethod]
        public void IsOutputLive_ReadsBothSpellings()
        {
            Assert.IsTrue(Fluke5322aReadings.IsOutputLive("ON"));
            Assert.IsTrue(Fluke5322aReadings.IsOutputLive("ON\r\n"));
            Assert.IsTrue(Fluke5322aReadings.IsOutputLive("1"));

            Assert.IsFalse(Fluke5322aReadings.IsOutputLive("OFF"));
            Assert.IsFalse(Fluke5322aReadings.IsOutputLive("0"));

            // Unreadable must report "not live" - erring towards de-energised.
            Assert.IsFalse(Fluke5322aReadings.IsOutputLive(null));
            Assert.IsFalse(Fluke5322aReadings.IsOutputLive("???"));
        }

        [TestMethod]
        public void UnitsForMode_FollowsWhatEachFunctionActuallySources()
        {
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, Fluke5322aReadings.UnitsForMode("GBR"));
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, Fluke5322aReadings.UnitsForMode("HRES"));
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, Fluke5322aReadings.UnitsForMode("LRES"));
            Assert.AreEqual(HardwareBL_Settings.Units_Voltage, Fluke5322aReadings.UnitsForMode("VOLT"));
            Assert.AreEqual(HardwareBL_Settings.Units_Current, Fluke5322aReadings.UnitsForMode("IDAC"));
            Assert.AreEqual(HardwareBL_Settings.Units_Current, Fluke5322aReadings.UnitsForMode("HIPL"));

            // The timer functions are seconds, which the broadcast vocabulary has no name for, so
            // they stay unlabelled rather than being relabelled as something they are not.
            Assert.AreEqual(string.Empty, Fluke5322aReadings.UnitsForMode("RCDT"));
            Assert.AreEqual(string.Empty, Fluke5322aReadings.UnitsForMode("HIPT"));

            // An unknown mode falls back to resistance: that is where this instrument spends nearly
            // all its time.
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, Fluke5322aReadings.UnitsForMode("WHAT"));
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, Fluke5322aReadings.UnitsForMode(null));
        }

        #endregion

        #region identification - the emulation-menu trap

        [TestMethod]
        public void Identification_MatchesBothModelNamesTheInstrumentCanReport()
        {
            // ⚠️ The model this unit reports is a menu setting: with 5320A emulation on, the SAME
            // instrument answers 5320A. Matching only 5322A would let an operator take the device
            // out of the server by flipping a front-panel option, with no error anywhere.
            Assert.IsTrue(HardwareDeviceHost.IsFluke5322a("FLUKE,5322A,650001217,0.045"));
            Assert.IsTrue(HardwareDeviceHost.IsFluke5322a("FLUKE,5320A,650001217,1.0+2.0+3.0+4.0"));
        }

        [TestMethod]
        public void Identification_DoesNotClaimTheOtherFlukes()
        {
            // The 5522A has its own BL, and the Hydra loggers answer "FLUKE," too.
            Assert.IsFalse(HardwareDeviceHost.IsFluke5322a("FLUKE,5522A,1972905,1.1+1.3+1.8"));
            Assert.IsFalse(HardwareDeviceHost.IsFluke5322a("FLUKE,2625A,1234567,1.0"));
            Assert.IsFalse(HardwareDeviceHost.IsFluke5322a(null));
            Assert.IsFalse(HardwareDeviceHost.IsFluke5322a(""));
        }

        [TestMethod]
        public void SettingsResolveTheFamilyFromTheIdentificationSN()
        {
            // Both emulation spellings are normalised to the single SN "5322A", so this one lookup
            // is what the settings and the BLCore token both key off.
            var settings = HardwareBL_Settings.CreateDefaultSettings();
            var family = settings.ResolveFamilyBySN("5322A");

            Assert.IsNotNull(family, "5322A must resolve to its own settings family");
            Assert.AreSame(settings.Fluke5322a, family);
            Assert.AreNotSame(settings.Fluke5522a, family, "the 5322A and the 5522A are different instruments");
            Assert.AreEqual(HardwareBL_Settings.Units_Resistance, settings.DefaultUnitsForDeviceSN("5322A"),
                "an electrical calibrator must not default to Celsius");
        }

        #endregion
    }
}
