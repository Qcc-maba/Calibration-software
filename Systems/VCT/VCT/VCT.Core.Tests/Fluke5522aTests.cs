using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the Fluke 5522A command builders and reply parsing. Every reply string below is what
    /// the instrument actually returned on 2026-09-03 (COM10, 9600 8-N-1, REMOTE I/F = comp).
    /// </summary>
    [TestClass]
    public class Fluke5522aTests
    {
        /// <summary>A real OUT? reply, captured from the instrument in standby.</summary>
        private const string RealOutputReply = "0.0000000E+00,V,0E+00,0,0.00E+00";

        #region safety — the property that matters most on a 1000 V source

        [TestMethod]
        public void InitSequence_NeverEnergisesTheOutput()
        {
            // This calibrator sources up to 1000 V and 20 A. OPER must never be reachable from an
            // init: the sequence may only reset, clear, or drive the instrument into standby.
            foreach (var step in Fluke5522aCommands.InitSequence)
            {
                var cmd = step.Build().Command.Trim();
                Assert.AreNotEqual("OPER", cmd, "init must never energise the output");
                StringAssert.Matches(cmd, new System.Text.RegularExpressions.Regex(@"^(\*RST|\*CLS|STBY)$"),
                    "unexpected init command: " + cmd);
            }
        }

        [TestMethod]
        public void InitSequence_EndsInStandby()
        {
            var last = Fluke5522aCommands.InitSequence[Fluke5522aCommands.InitSequence.Length - 1].Build().Command;
            Assert.AreEqual("STBY", last.Trim(),
                "the de-energised end state should be stated, not left as a side effect of *RST");
        }

        [TestMethod]
        public void Operate_IsBuiltButIsolated()
        {
            // It exists — a calibration target needs it — and it is exactly the one command the BL
            // never issues on its own.
            Assert.AreEqual("OPER", Fluke5522aCommands.BuildOperate().Command);
            Assert.AreEqual("STBY", Fluke5522aCommands.BuildStandby().Command);
        }

        [TestMethod]
        public void SettingAnOutputDoesNotEnergiseIt()
        {
            // OUT only selects the value; the terminals stay disconnected until OPER.
            var cmd = Fluke5522aCommands.BuildSetOutput(10, "V").Command;
            Assert.AreEqual("OUT 10 V", cmd);
            Assert.IsFalse(cmd.Contains("OPER"));
        }

        #endregion

        #region commands

        [TestMethod]
        public void Build_VerifiedQueries()
        {
            Assert.AreEqual("*IDN?", HydraProtocolHelper.Build_F5522a_Identify().Command);
            Assert.AreEqual("*OPT?", HydraProtocolHelper.Build_F5522a_QueryOptions().Command);
            Assert.AreEqual("OUT?", HydraProtocolHelper.Build_F5522a_QueryOutput().Command);
            Assert.AreEqual("OPER?", HydraProtocolHelper.Build_F5522a_QueryOperate().Command);
            Assert.AreEqual("FUNC?", HydraProtocolHelper.Build_F5522a_QueryFunction().Command);
            Assert.AreEqual("RANGE?", HydraProtocolHelper.Build_F5522a_QueryRange().Command);
            Assert.AreEqual("ERR?", HydraProtocolHelper.Build_F5522a_ReadError().Command);
            Assert.AreEqual("FAULT?", HydraProtocolHelper.Build_F5522a_ReadFault().Command);
        }

        [TestMethod]
        public void Build_AcOutput_CarriesValueAndFrequency()
        {
            Assert.AreEqual("OUT 1.5 V, 50 HZ",
                HydraProtocolHelper.Build_F5522a_SetOutput(1.5, "V", 50).Command);
        }

        [TestMethod]
        public void Build_SetOutput_IsCultureInvariant()
        {
            // A he-IL decimal separator would send "OUT 1,5 V" and the comma would split the command
            // into two parameters.
            StringAssert.Contains(HydraProtocolHelper.Build_F5522a_SetOutput(1.5, "V").Command, "1.5");
        }

        #endregion

        #region reply parsing

        [TestMethod]
        public void TryParseOutput_ReadsTheRealReply()
        {
            Fluke5522aReadings.OutputSetting s;
            Assert.IsTrue(Fluke5522aReadings.TryParseOutput(RealOutputReply, out s));
            Assert.AreEqual(0.0, s.Amplitude, 1e-12);
            Assert.AreEqual("V", s.Unit);
            Assert.AreEqual(0.0, s.Frequency, 1e-12);
        }

        [TestMethod]
        public void TryParseOutput_ReadsAnAcSetpoint()
        {
            Fluke5522aReadings.OutputSetting s;
            Assert.IsTrue(Fluke5522aReadings.TryParseOutput("1.0000000E+01,V,0E+00,0,5.00E+01", out s));
            Assert.AreEqual(10.0, s.Amplitude, 1e-9);
            Assert.AreEqual("V", s.Unit);
            Assert.AreEqual(50.0, s.Frequency, 1e-9);
        }

        [TestMethod]
        public void TryParseOutput_GarbageIsNotAZeroSetpoint()
        {
            // 0 V is a perfectly plausible setpoint on a calibrator, so a failed parse must never
            // become one.
            Fluke5522aReadings.OutputSetting s;
            Assert.IsFalse(Fluke5522aReadings.TryParseOutput("", out s));
            Assert.IsFalse(Fluke5522aReadings.TryParseOutput(null, out s));
            Assert.IsFalse(Fluke5522aReadings.TryParseOutput("FLUKE,5522A", out s));
            Assert.IsFalse(Fluke5522aReadings.TryParseOutput("0.0000000E+00", out s)); // no unit field
        }

        [TestMethod]
        public void IsOutputLive_ReadsTheOperateState()
        {
            Assert.IsFalse(Fluke5522aReadings.IsOutputLive("0"));   // measured: standby
            Assert.IsTrue(Fluke5522aReadings.IsOutputLive("1"));
            Assert.IsFalse(Fluke5522aReadings.IsOutputLive(""));
            Assert.IsFalse(Fluke5522aReadings.IsOutputLive(null));
        }

        [TestMethod]
        public void IsNoError_MatchesTheEmptyQueueReply()
        {
            Assert.IsTrue(Fluke5522aReadings.IsNoError("0,\"No Error\""));
            Assert.IsFalse(Fluke5522aReadings.IsNoError("321,\"20A Terminals must be shorted\""));
            Assert.IsFalse(Fluke5522aReadings.IsNoError(null));
        }

        [TestMethod]
        public void NormalizeUnit_MapsToTheServerVocabulary()
        {
            Assert.AreEqual("Volt", Fluke5522aReadings.NormalizeUnit("V"));
            Assert.AreEqual("Ampere", Fluke5522aReadings.NormalizeUnit("A"));
            Assert.AreEqual("Ohm", Fluke5522aReadings.NormalizeUnit("OHM"));
            Assert.AreEqual("Hertz", Fluke5522aReadings.NormalizeUnit("HZ"));
            Assert.AreEqual("Celsius", Fluke5522aReadings.NormalizeUnit("CEL"));
            // An unrecognised unit keeps the instrument's own spelling rather than being relabelled.
            Assert.AreEqual("DBM", Fluke5522aReadings.NormalizeUnit("DBM"));
        }

        #endregion

        #region identification and units

        [TestMethod]
        public void TheCalibratorResolvesToItsOwnFamily_NotTheHydraLoggers()
        {
            // Both answer "FLUKE,..." — the Hydra loggers as "FLUKE,2625A" / "FLUKE,2638A".
            var s = HardwareBL_Settings.CreateDefaultSettings();
            Assert.AreSame(s.Fluke5522a, s.ResolveFamilyBySN("5522A"));
            Assert.AreSame(s.Hydra2type, s.ResolveFamilyBySN("FLUKE,2625A"));
            Assert.AreEqual("Volt", s.DefaultUnitsForDeviceSN("5522A"));
        }

        #endregion
    }
}
