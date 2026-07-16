using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the 34401A command builders in <see cref="HydraProtocolHelper"/>, including a
    /// regression guard for the malformed autorange SCPI that was fixed.
    /// </summary>
    [TestClass]
    public class HydraProtocolHelper34401aTests
    {
        #region reset / remote / clear / read

        [TestMethod]
        public void Build_ReadValue_ReturnsScpiReadQuery()
        {
            var p = HydraProtocolHelper.Build_ReadValue();
            Assert.AreEqual("READ?", p.Command);
            Assert.IsTrue(p.Wait4Respons);
        }

        [TestMethod]
        public void Build_ResetPacket_ReturnsRst()
        {
            Assert.AreEqual("*RST", HydraProtocolHelper.Build_ResetPacket(false).Command);
        }

        [TestMethod]
        public void Build_RemotePacket_ReturnsSystRemote()
        {
            // Mandatory over RS-232, else the 34401A raises error 550 "Command not allowed in local".
            Assert.AreEqual("SYSt:REM", HydraProtocolHelper.Build_RemotePacket().Command);
        }

        [TestMethod]
        public void BuildClearBuffer_ReturnsCls()
        {
            Assert.AreEqual("*CLS", HydraProtocolHelper.buildClearBuffer().Command);
        }

        #endregion

        #region CONF per sensor type

        [TestMethod]
        public void Build_Configuration_Vdc_ReturnsConfVoltDc()
        {
            var s = new SensorType
            {
                MeasureType = SensorType.MeasureTypes.VDC,
                SensType = SensorType.SensorTypes.None
            };
            Assert.AreEqual("CONF:VOLT:DC", HydraProtocolHelper.Build_Configuration(s).Command);
        }

        [TestMethod]
        public void Build_Configuration_Rtd_ReturnsConfRes()
        {
            var s = new SensorType { SensType = SensorType.SensorTypes.RTD }; // 2-wire
            Assert.AreEqual("CONF:RES", HydraProtocolHelper.Build_Configuration(s).Command);
        }

        [TestMethod]
        public void Build_Configuration_Frtd_ReturnsConfFres()
        {
            var s = new SensorType { SensType = SensorType.SensorTypes.FRTD }; // 4-wire
            Assert.AreEqual("CONF:FRES", HydraProtocolHelper.Build_Configuration(s).Command);
        }

        #endregion

        #region AutoRange (regression: no stray spaces in the SCPI mnemonic)

        [TestMethod]
        public void Build_AutoRange_Vdc_HasNoStraySpaces()
        {
            var s = new SensorType
            {
                MeasureType = SensorType.MeasureTypes.VDC,
                SensType = SensorType.SensorTypes.None
            };
            var cmd = HydraProtocolHelper.Build_AutoRange(s).Command;

            Assert.AreEqual("VOLT:DC:RANG:AUTO ON", cmd);
            // Old bug was "VOLT: DC: RANG: AUTO ON" — the 34401A rejects spaces inside the mnemonic.
            Assert.IsFalse(cmd.Contains(": "), "SCPI mnemonic must not contain ': '");
        }

        [TestMethod]
        public void Build_AutoRange_Rtd_ReturnsResAutoRange()
        {
            var s = new SensorType { SensType = SensorType.SensorTypes.RTD };
            Assert.AreEqual("RES:RANG:AUTO ON", HydraProtocolHelper.Build_AutoRange(s).Command.Trim());
        }

        #endregion
    }
}
