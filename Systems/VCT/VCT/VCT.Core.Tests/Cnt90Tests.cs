using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Device;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the Pendulum CNT-90 command builders and reading interpretation. Command text is per the
    /// CNT-90 Programmer's Handbook and was verified live against the instrument at GPIB address 7.
    /// </summary>
    [TestClass]
    public class Cnt90Tests
    {
        #region common commands

        [TestMethod]
        public void Build_Reset_And_Clear()
        {
            Assert.AreEqual("*RST", HydraProtocolHelper.Build_Cnt90_Reset().Command);
            Assert.AreEqual("*CLS", HydraProtocolHelper.Build_Cnt90_ClearStatus().Command);
        }

        [TestMethod]
        public void Build_Identify_And_Error_AreQueries()
        {
            var idn = HydraProtocolHelper.Build_Cnt90_Identify();
            Assert.AreEqual("*IDN?", idn.Command);
            Assert.IsTrue(idn.Wait4Respons);

            var err = HydraProtocolHelper.Build_Cnt90_ReadError();
            Assert.AreEqual(":SYSTem:ERRor?", err.Command);
            Assert.IsTrue(err.Wait4Respons);
        }

        [TestMethod]
        public void Build_SelectNativeLanguage_AvoidsTheEmulationCommandSet()
        {
            // COMPatible is Agilent 53131/53132 emulation with a different command set entirely, so
            // the BL pins the unit to the command set this code actually speaks.
            Assert.AreEqual(":SYSTem:LANGuage NATive",
                HydraProtocolHelper.Build_Cnt90_SelectNativeLanguage().Command);
        }

        #endregion

        #region measurement timeout

        [TestMethod]
        public void Build_TimeoutCommands()
        {
            // *RST leaves the measurement timeout OFF, so the BL arms it explicitly.
            Assert.AreEqual(":SYSTem:TOUT ON", HydraProtocolHelper.Build_Cnt90_TimeoutOn().Command);
            Assert.AreEqual(":SYSTem:TOUT:AUTO ON", HydraProtocolHelper.Build_Cnt90_TimeoutAuto().Command);
            Assert.AreEqual(":SYSTem:TOUT:TIME 1", HydraProtocolHelper.Build_Cnt90_TimeoutTime(1).Command);
            Assert.AreEqual(":SYSTem:TOUT:TIME 0.5", HydraProtocolHelper.Build_Cnt90_TimeoutTime(0.5).Command);
        }

        [TestMethod]
        public void Build_TimeoutTime_IsCultureInvariant()
        {
            // A he-IL decimal separator would produce ":SYSTem:TOUT:TIME 0,5" and split the command
            // into two parameters.
            StringAssert.Contains(HydraProtocolHelper.Build_Cnt90_TimeoutTime(0.25).Command, "0.25");
        }

        #endregion

        #region measurement queries

        [TestMethod]
        public void Build_MeasureFrequency_CarriesTheInputAsAParameter()
        {
            var p = HydraProtocolHelper.Build_Cnt90_MeasureFrequency(1);
            Assert.AreEqual(":MEASure:FREQuency? (@1)", p.Command);
            Assert.IsTrue(p.Wait4Respons);
        }

        [TestMethod]
        public void Build_MeasureFrequency_QuestionMarkIsNotLast()
        {
            // Regression guard for the transport: a '?' in the middle of the command still marks a
            // query. GpibCom used to test EndsWith("?") and would have read no reply at all.
            var cmd = HydraProtocolHelper.Build_Cnt90_MeasureFrequency(2).Command;
            Assert.IsFalse(cmd.EndsWith("?"));
            Assert.IsTrue(Maba.VCT.ComLayer.GpibCom.IsQuery(cmd));
        }

        [TestMethod]
        public void Build_ConfigureAndRead()
        {
            Assert.AreEqual(":CONFigure:FREQuency (@1)",
                HydraProtocolHelper.Build_Cnt90_ConfigureFrequency(1).Command);
            Assert.AreEqual(":READ?", HydraProtocolHelper.Build_Cnt90_Read().Command);
        }

        [TestMethod]
        public void Build_VoltageProbe_IsTheSignalPresenceCheck()
        {
            Assert.AreEqual(":MEASure:VOLTage:MAXimum? (@1)",
                HydraProtocolHelper.Build_Cnt90_MeasureVoltageMax(1).Command);
            Assert.AreEqual(":MEASure:VOLTage:MINimum? (@2)",
                HydraProtocolHelper.Build_Cnt90_MeasureVoltageMin(2).Command);
        }

        #endregion

        #region reading interpretation

        [TestMethod]
        public void IsValidChannel_OnlyTheTwoMeasurementInputs()
        {
            Assert.IsTrue(Cnt90Readings.IsValidChannel(1));
            Assert.IsTrue(Cnt90Readings.IsValidChannel(2));
            Assert.IsFalse(Cnt90Readings.IsValidChannel(0));
            Assert.IsFalse(Cnt90Readings.IsValidChannel(3)); // prescaler
            Assert.IsFalse(Cnt90Readings.IsValidChannel(4)); // rear arming input
        }

        [TestMethod]
        public void IsNoResult_CatchesTheSentinelAndNonFiniteValues()
        {
            Assert.IsTrue(Cnt90Readings.IsNoResult(Cnt90Readings.NoResultValue));
            Assert.IsTrue(Cnt90Readings.IsNoResult(9.91e37));
            Assert.IsTrue(Cnt90Readings.IsNoResult(double.NaN));
            Assert.IsTrue(Cnt90Readings.IsNoResult(double.PositiveInfinity));

            Assert.IsFalse(Cnt90Readings.IsNoResult(0));
            Assert.IsFalse(Cnt90Readings.IsNoResult(1.0e7));   // 10 MHz
            Assert.IsFalse(Cnt90Readings.IsNoResult(-2.5e-3));
        }

        [TestMethod]
        public void IndicatesSignalPresent_SeparatesAnOpenInputFromARealSignal()
        {
            // Measured on an open input: -4 mV to -2 mV of noise.
            Assert.IsFalse(Cnt90Readings.IndicatesSignalPresent(-0.004));
            Assert.IsFalse(Cnt90Readings.IndicatesSignalPresent(0.002));
            Assert.IsFalse(Cnt90Readings.IndicatesSignalPresent(0));

            Assert.IsTrue(Cnt90Readings.IndicatesSignalPresent(2.0));
            Assert.IsTrue(Cnt90Readings.IndicatesSignalPresent(-1.0));
        }

        [TestMethod]
        public void IndicatesSignalPresent_RejectsTheNoResultSentinel()
        {
            // A sentinel is not a large signal.
            Assert.IsFalse(Cnt90Readings.IndicatesSignalPresent(Cnt90Readings.NoResultValue));
            Assert.IsFalse(Cnt90Readings.IndicatesSignalPresent(double.NaN));
        }

        [TestMethod]
        public void TryParseValue_ReadsNr3AndRejectsGarbage()
        {
            double v;
            Assert.IsTrue(Cnt90Readings.TryParseValue("+1.0000000000000E+07\r\n", out v));
            Assert.AreEqual(1.0e7, v, 1e-3);

            Assert.IsTrue(Cnt90Readings.TryParseValue("-4E-03", out v));
            Assert.AreEqual(-0.004, v, 1e-9);

            Assert.IsFalse(Cnt90Readings.TryParseValue("", out v));
            Assert.IsFalse(Cnt90Readings.TryParseValue(null, out v));
            Assert.IsFalse(Cnt90Readings.TryParseValue("not a number", out v));
        }

        #endregion
    }
}
