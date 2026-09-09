using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using System.Collections.Generic;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the Siglent SDG6052X command builders and — the part that matters — parsing its replies,
    /// which echo the command header and glue units onto every number. Reply strings below are exactly
    /// what the instrument returned on 2026-09-01.
    /// </summary>
    [TestClass]
    public class Sdg6052xTests
    {
        /// <summary>A real C1:BSWV? reply, captured from the instrument.</summary>
        private const string RealBswvReply =
            "C1:BSWV WVTP,SINE,FRQ,1000HZ,PERI,0.001S,AMP,4V,AMPVRMS,1.414Vrms,MAX_OUTPUT_AMP,20V,OFST,0V,HLEV,2V,LLEV,-2V,PHSE,0";

        #region commands

        [TestMethod]
        public void Build_Queries()
        {
            Assert.AreEqual("*IDN?", HydraProtocolHelper.Build_Sdg_Identify().Command);
            Assert.AreEqual("SYST:ERR?", HydraProtocolHelper.Build_Sdg_ReadError().Command);
            Assert.AreEqual("C1:BSWV?", HydraProtocolHelper.Build_Sdg_QueryBasicWave(1).Command);
            Assert.AreEqual("C2:OUTP?", HydraProtocolHelper.Build_Sdg_QueryOutput(2).Command);
        }

        [TestMethod]
        public void Build_Setters_UseSiglentShorthand()
        {
            Assert.AreEqual("C1:BSWV FRQ,1000", HydraProtocolHelper.Build_Sdg_SetFrequency(1, 1000).Command);
            Assert.AreEqual("C1:BSWV AMP,4", HydraProtocolHelper.Build_Sdg_SetAmplitude(1, 4).Command);
            Assert.AreEqual("C2:BSWV OFST,-0.5", HydraProtocolHelper.Build_Sdg_SetOffset(2, -0.5).Command);
            Assert.AreEqual("C1:BSWV WVTP,SINE", HydraProtocolHelper.Build_Sdg_SetWaveType(1, "SINE").Command);
            Assert.AreEqual("C1:OUTP LOAD,50", HydraProtocolHelper.Build_Sdg_SetLoad(1, "50").Command);
        }

        [TestMethod]
        public void Build_SetFrequency_IsCultureInvariant()
        {
            StringAssert.Contains(HydraProtocolHelper.Build_Sdg_SetFrequency(1, 1234.5).Command, "1234.5");
        }

        [TestMethod]
        public void Build_OutputCommands()
        {
            Assert.AreEqual("C1:OUTP ON", HydraProtocolHelper.Build_Sdg_OutputOn(1).Command);
            Assert.AreEqual("C2:OUTP OFF", HydraProtocolHelper.Build_Sdg_OutputOff(2).Command);
        }

        [TestMethod]
        public void InitSequence_NeverResetsAndNeverEnablesAnOutput()
        {
            // *RST on the SDG restores factory defaults and would discard the operator's front-panel
            // setup; an output enable energises a cable. Neither belongs in an init.
            foreach (var step in Sdg6052xCommands.InitSequence)
            {
                var cmd = step.Build().Command;
                Assert.AreNotEqual("*RST", cmd, "init must not reset the generator");
                Assert.IsFalse(cmd.Contains("OUTP ON"), "init must not energise an output");
            }
        }

        #endregion

        #region reply parsing — the reason this class exists

        [TestMethod]
        public void StripHeader_RemovesTheEchoedCommand()
        {
            Assert.AreEqual("OFF,LOAD,HZ,PLRT,NOR", Sdg6052xReplies.StripHeader("C1:OUTP OFF,LOAD,HZ,PLRT,NOR"));
            StringAssert.StartsWith(Sdg6052xReplies.StripHeader(RealBswvReply), "WVTP,SINE");
        }

        [TestMethod]
        public void StripHeader_LeavesAHeaderlessReplyAlone()
        {
            // A unit with COMM_HEADER switched off answers bare values.
            Assert.AreEqual("WVTP,SINE,FRQ,1000HZ", Sdg6052xReplies.StripHeader("WVTP,SINE,FRQ,1000HZ"));
            Assert.AreEqual("", Sdg6052xReplies.StripHeader(null));
        }

        [TestMethod]
        public void ParseParameters_ReadsTheRealReply()
        {
            var p = Sdg6052xReplies.ParseParameters(RealBswvReply);

            Assert.AreEqual("SINE", p["WVTP"]);
            Assert.AreEqual("1000HZ", p["FRQ"]);
            Assert.AreEqual("4V", p["AMP"]);
            Assert.AreEqual("0V", p["OFST"]);
            Assert.AreEqual("-2V", p["LLEV"]);
        }

        [TestMethod]
        public void TryGetNumeric_StripsTheUnitSuffix()
        {
            var p = Sdg6052xReplies.ParseParameters(RealBswvReply);
            double v;

            // double.Parse("1000HZ") throws — this is the whole point of the helper.
            Assert.IsTrue(Sdg6052xReplies.TryGetNumeric(p, "FRQ", out v));
            Assert.AreEqual(1000.0, v, 1e-9);

            Assert.IsTrue(Sdg6052xReplies.TryGetNumeric(p, "AMP", out v));
            Assert.AreEqual(4.0, v, 1e-9);

            Assert.IsTrue(Sdg6052xReplies.TryGetNumeric(p, "PERI", out v));
            Assert.AreEqual(0.001, v, 1e-12);

            Assert.IsTrue(Sdg6052xReplies.TryGetNumeric(p, "AMPVRMS", out v));
            Assert.AreEqual(1.414, v, 1e-9);

            Assert.IsTrue(Sdg6052xReplies.TryGetNumeric(p, "LLEV", out v));
            Assert.AreEqual(-2.0, v, 1e-9);
        }

        [TestMethod]
        public void TryGetNumeric_MissingKeyIsNotZero()
        {
            var p = Sdg6052xReplies.ParseParameters(RealBswvReply);
            double v;
            Assert.IsFalse(Sdg6052xReplies.TryGetNumeric(p, "NOSUCHKEY", out v));
            Assert.IsFalse(Sdg6052xReplies.TryGetNumeric(p, "WVTP", out v)); // "SINE" is not a number
            Assert.IsFalse(Sdg6052xReplies.TryGetNumeric(null, "FRQ", out v));
        }

        [TestMethod]
        public void TryParseNumber_HandlesExponentsAndUnits()
        {
            double v;
            Assert.IsTrue(Sdg6052xReplies.TryParseNumber("1.5E+03HZ", out v));
            Assert.AreEqual(1500.0, v, 1e-9);

            Assert.IsTrue(Sdg6052xReplies.TryParseNumber("-2.5E-3S", out v));
            Assert.AreEqual(-0.0025, v, 1e-12);

            Assert.IsTrue(Sdg6052xReplies.TryParseNumber("0", out v));
            Assert.AreEqual(0.0, v, 1e-12);

            Assert.IsFalse(Sdg6052xReplies.TryParseNumber("SINE", out v));
            Assert.IsFalse(Sdg6052xReplies.TryParseNumber("", out v));
            Assert.IsFalse(Sdg6052xReplies.TryParseNumber(null, out v));
        }

        [TestMethod]
        public void IsOutputOn_ReadsTheStatePositionally()
        {
            Assert.IsFalse(Sdg6052xReplies.IsOutputOn("C1:OUTP OFF,LOAD,HZ,PLRT,NOR"));
            Assert.IsTrue(Sdg6052xReplies.IsOutputOn("C1:OUTP ON,LOAD,50,PLRT,NOR"));
            Assert.IsFalse(Sdg6052xReplies.IsOutputOn(""));
        }

        [TestMethod]
        public void IsValidChannel_TwoOutputs()
        {
            Assert.IsTrue(Sdg6052xReplies.IsValidChannel(1));
            Assert.IsTrue(Sdg6052xReplies.IsValidChannel(2));
            Assert.IsFalse(Sdg6052xReplies.IsValidChannel(0));
            Assert.IsFalse(Sdg6052xReplies.IsValidChannel(3));
        }

        #endregion

        #region setpoint selection

        private static HardwareBL_DeviceType Family(SensorType.MeasureTypes type)
        {
            return new HardwareBL_DeviceType
            {
                Channels = new List<int> { 1 },
                Sensor = new SensorType { MeasureType = type, SensType = SensorType.SensorTypes.None }
            };
        }

        [TestMethod]
        public void TryReadSetpoint_FrequencySourceReportsFrq()
        {
            double v;
            Assert.IsTrue(Sdg6052xCommands.TryReadSetpoint(RealBswvReply, Family(SensorType.MeasureTypes.Frequency), out v));
            Assert.AreEqual(1000.0, v, 1e-9);
        }

        [TestMethod]
        public void TryReadSetpoint_VoltageSourceReportsAmp()
        {
            double v;
            Assert.IsTrue(Sdg6052xCommands.TryReadSetpoint(RealBswvReply, Family(SensorType.MeasureTypes.VoltagePP), out v));
            Assert.AreEqual(4.0, v, 1e-9);
        }

        [TestMethod]
        public void TryReadSetpoint_DefaultsToFrequencyWhenUnconfigured()
        {
            double v;
            Assert.IsTrue(Sdg6052xCommands.TryReadSetpoint(RealBswvReply, null, out v));
            Assert.AreEqual(1000.0, v, 1e-9);
        }

        [TestMethod]
        public void TryReadSetpoint_GarbledReplyYieldsNothing()
        {
            double v;
            Assert.IsFalse(Sdg6052xCommands.TryReadSetpoint("", Family(SensorType.MeasureTypes.Frequency), out v));
            Assert.IsFalse(Sdg6052xCommands.TryReadSetpoint("C1:BSWV WVTP,SINE", Family(SensorType.MeasureTypes.Frequency), out v));
        }

        #endregion
    }
}
