using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.ComLayer;
using Maba.VCT.Core.Device;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the two pure decisions the USBTMC path depends on: telling a SCPI query from a command,
    /// and recognising the Keysight 1000 X-Series identification reply. Both are regression guards for
    /// bugs found while bringing the EDU-X 1002A up on real hardware (2026-09-01).
    /// </summary>
    [TestClass]
    public class VisaTransportTests
    {
        #region query detection

        [TestMethod]
        public void IsQuery_ParameterisedQuery_IsRecognised()
        {
            // The bug: ':MEASure:VPP? CHANnel1' does not END with '?', so an EndsWith test read no
            // reply, the session kept waiting and acquisition stalled after one measurement.
            Assert.IsTrue(VisaCom.IsQuery(":MEASure:VPP? CHANnel1"));
            Assert.IsTrue(VisaCom.IsQuery(":MEASure:VRMS? DISPlay,AC,CHANnel2"));
            Assert.IsTrue(VisaCom.IsQuery(":MEASure:VAVerage? DISPlay,CHANnel1"));
        }

        [TestMethod]
        public void IsQuery_TrailingQuestionMark_IsRecognised()
        {
            Assert.IsTrue(VisaCom.IsQuery("*IDN?"));
            Assert.IsTrue(VisaCom.IsQuery("*OPC?"));
            Assert.IsTrue(VisaCom.IsQuery(":SYSTem:ERRor?"));
        }

        [TestMethod]
        public void IsQuery_PlainCommands_ExpectNoReply()
        {
            Assert.IsFalse(VisaCom.IsQuery("*RST"));
            Assert.IsFalse(VisaCom.IsQuery("*CLS"));
            Assert.IsFalse(VisaCom.IsQuery(":AUToscale"));
            Assert.IsFalse(VisaCom.IsQuery(":RUN"));
            Assert.IsFalse(VisaCom.IsQuery(":CHANnel1:DISPlay 1"));
            Assert.IsFalse(VisaCom.IsQuery(":TIMebase:MODE MAIN"));
            Assert.IsFalse(VisaCom.IsQuery(null));
        }

        #endregion

        #region 1000 X-Series identification

        [TestMethod]
        public void IsKeysight1000XSeries_MatchesTheRealIdnReply()
        {
            // Verified live: the instrument spells its model "EDU-X 1002A", with a hyphen and a space,
            // not "EDUX1002A" as the datasheet model number does.
            Assert.IsTrue(HardwareDeviceHost.IsKeysight1000XSeries(
                "KEYSIGHT TECHNOLOGIES,EDU-X 1002A,CN59280205,01.10.2018012838"));
        }

        [TestMethod]
        public void IsKeysight1000XSeries_MatchesTheDatasheetSpellingToo()
        {
            Assert.IsTrue(HardwareDeviceHost.IsKeysight1000XSeries(
                "KEYSIGHT TECHNOLOGIES,EDUX1002A,CN59280205,01.10"));
            Assert.IsTrue(HardwareDeviceHost.IsKeysight1000XSeries(
                "KEYSIGHT TECHNOLOGIES,EDUX1002G,CN12345678,01.10"));
        }

        [TestMethod]
        public void IsKeysight1000XSeries_DoesNotClaimOtherInstruments()
        {
            Assert.IsFalse(HardwareDeviceHost.IsKeysight1000XSeries("HEWLETT-PACKARD,34401A,0,10-5-2"));
            Assert.IsFalse(HardwareDeviceHost.IsKeysight1000XSeries("WAVETEK,9100,1234,5.12"));
            Assert.IsFalse(HardwareDeviceHost.IsKeysight1000XSeries("FLUKE,2625A,0,1.0"));
            Assert.IsFalse(HardwareDeviceHost.IsKeysight1000XSeries("KEYSIGHT TECHNOLOGIES,DSOX1102A,CN1,01.10"));
            Assert.IsFalse(HardwareDeviceHost.IsKeysight1000XSeries(""));
            Assert.IsFalse(HardwareDeviceHost.IsKeysight1000XSeries(null));
        }

        #endregion
    }
}
