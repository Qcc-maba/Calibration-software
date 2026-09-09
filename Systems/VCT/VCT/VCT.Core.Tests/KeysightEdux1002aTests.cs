using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the Keysight EDUX1002A command builders and the pure reading-interpretation helpers.
    /// Command text is per the InfiniiVision 1000 X-Series Programmer's Guide (Keysight 9018-07554).
    /// </summary>
    [TestClass]
    public class KeysightEdux1002aTests
    {
        #region common commands

        [TestMethod]
        public void Build_Reset_ReturnsRst()
        {
            var p = HydraProtocolHelper.Build_Edux1002a_Reset();
            Assert.AreEqual("*RST", p.Command);
            Assert.IsFalse(p.Wait4Respons, "*RST is a command, not a query.");
        }

        [TestMethod]
        public void Build_ClearStatus_ReturnsCls()
        {
            Assert.AreEqual("*CLS", HydraProtocolHelper.Build_Edux1002a_ClearStatus().Command);
        }

        [TestMethod]
        public void Build_Identify_IsAQuery()
        {
            var p = HydraProtocolHelper.Build_Edux1002a_Identify();
            Assert.AreEqual("*IDN?", p.Command);
            Assert.IsTrue(p.Wait4Respons);
        }

        [TestMethod]
        public void Build_ReadError_ReturnsSystemErrorQuery()
        {
            var p = HydraProtocolHelper.Build_Edux1002a_ReadError();
            Assert.AreEqual(":SYSTem:ERRor?", p.Command);
            Assert.IsTrue(p.Wait4Respons);
        }

        #endregion

        #region acquisition setup

        [TestMethod]
        public void Build_TimebaseMain_SelectsMainSweep()
        {
            Assert.AreEqual(":TIMebase:MODE MAIN", HydraProtocolHelper.Build_Edux1002a_TimebaseMain().Command);
        }

        [TestMethod]
        public void Build_AutoScale_ReturnsAutoscale()
        {
            Assert.AreEqual(":AUToscale", HydraProtocolHelper.Build_Edux1002a_AutoScale().Command);
        }

        [TestMethod]
        public void Build_RunAndStop_ReturnTheRunControlCommands()
        {
            Assert.AreEqual(":RUN", HydraProtocolHelper.Build_Edux1002a_Run().Command);
            Assert.AreEqual(":STOP", HydraProtocolHelper.Build_Edux1002a_Stop().Command);
        }

        [TestMethod]
        public void Build_ChannelDisplay_TurnsAChannelOnAndOff()
        {
            Assert.AreEqual(":CHANnel1:DISPlay 1", HydraProtocolHelper.Build_Edux1002a_ChannelDisplay(1, true).Command);
            Assert.AreEqual(":CHANnel2:DISPlay 0", HydraProtocolHelper.Build_Edux1002a_ChannelDisplay(2, false).Command);
        }

        [TestMethod]
        public void Build_SetMeasureSource_TargetsTheChannel()
        {
            Assert.AreEqual(":MEASure:SOURce CHANnel2", HydraProtocolHelper.Build_Edux1002a_SetMeasureSource(2).Command);
        }

        #endregion

        #region measurement queries per configured quantity

        private static SensorType Sensor(SensorType.MeasureTypes type)
        {
            return new SensorType { MeasureType = type, SensType = SensorType.SensorTypes.None };
        }

        [TestMethod]
        public void Build_Measure_PeakToPeak()
        {
            var p = HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(SensorType.MeasureTypes.VoltagePP), 1);
            Assert.AreEqual(":MEASure:VPP? CHANnel1", p.Command);
            Assert.IsTrue(p.Wait4Respons, "A measurement query must wait for the reply.");
        }

        [TestMethod]
        public void Build_Measure_Rms_IsAcOverTheDisplayedWaveform()
        {
            Assert.AreEqual(":MEASure:VRMS? DISPlay,AC,CHANnel2",
                HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(SensorType.MeasureTypes.VoltageRMS), 2).Command);
        }

        [TestMethod]
        public void Build_Measure_VoltageDc_UsesTheAverageOverTheScreen()
        {
            Assert.AreEqual(":MEASure:VAVerage? DISPlay,CHANnel1",
                HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(SensorType.MeasureTypes.VoltageDC), 1).Command);
        }

        [TestMethod]
        public void Build_Measure_LegacyVdc_IsNotAScopeVoltageMeasurement()
        {
            // VDC means "resistance converted to a temperature" in this codebase (see
            // HydraCalculations.ProcessResults), so the scope must not answer it with a voltage
            // query - it falls through to the peak-to-peak default like any other unsupported type.
            Assert.AreEqual(":MEASure:VPP? CHANnel1",
                HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(SensorType.MeasureTypes.VDC), 1).Command);
        }

        [TestMethod]
        public void Build_Measure_Frequency()
        {
            Assert.AreEqual(":MEASure:FREQuency? CHANnel1",
                HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(SensorType.MeasureTypes.Frequency), 1).Command);
        }

        [TestMethod]
        public void Build_Measure_UnsetOrUnsupportedSensor_FallsBackToPeakToPeak()
        {
            Assert.AreEqual(":MEASure:VPP? CHANnel1",
                HydraProtocolHelper.Build_Edux1002a_Measure(null, 1).Command);
            Assert.AreEqual(":MEASure:VPP? CHANnel1",
                HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(SensorType.MeasureTypes.TEMP), 1).Command);
        }

        [TestMethod]
        public void Build_Measure_AlwaysCarriesAnExplicitSource()
        {
            // Without an explicit source a reply could be attributed to the wrong channel while the
            // round-robin loop is mid-flight.
            foreach (var type in new[]
                     {
                         SensorType.MeasureTypes.VoltagePP,
                         SensorType.MeasureTypes.VoltageRMS,
                         SensorType.MeasureTypes.VoltageDC,
                         SensorType.MeasureTypes.Frequency,
                     })
            {
                var cmd = HydraProtocolHelper.Build_Edux1002a_Measure(Sensor(type), 2).Command;
                StringAssert.Contains(cmd, "CHANnel2", type + " must name its source");
            }
        }

        #endregion

        #region reading interpretation

        [TestMethod]
        public void IsMeasurementError_TrueForTheCannotMeasureSentinel()
        {
            // The scope answers +9.9E+37 when the waveform it needs is not on screen.
            Assert.IsTrue(KeysightEdux1002aReadings.IsMeasurementError(9.9e37));
            Assert.IsTrue(KeysightEdux1002aReadings.IsMeasurementError(KeysightEdux1002aReadings.MeasurementErrorValue));
            Assert.IsTrue(KeysightEdux1002aReadings.IsMeasurementError(double.NaN));
            Assert.IsTrue(KeysightEdux1002aReadings.IsMeasurementError(double.PositiveInfinity));
        }

        [TestMethod]
        public void IsMeasurementError_FalseForRealReadings()
        {
            Assert.IsFalse(KeysightEdux1002aReadings.IsMeasurementError(0));
            Assert.IsFalse(KeysightEdux1002aReadings.IsMeasurementError(1.24));
            Assert.IsFalse(KeysightEdux1002aReadings.IsMeasurementError(-5.0));
            Assert.IsFalse(KeysightEdux1002aReadings.IsMeasurementError(1.0e6)); // 1 MHz frequency reading
        }

        [TestMethod]
        public void IsValidChannel_OnlyTheTwoAnalogChannels()
        {
            Assert.AreEqual(2, KeysightEdux1002aReadings.AnalogChannelCount);
            Assert.IsTrue(KeysightEdux1002aReadings.IsValidChannel(1));
            Assert.IsTrue(KeysightEdux1002aReadings.IsValidChannel(2));
            Assert.IsFalse(KeysightEdux1002aReadings.IsValidChannel(0));
            Assert.IsFalse(KeysightEdux1002aReadings.IsValidChannel(3));
            Assert.IsFalse(KeysightEdux1002aReadings.IsValidChannel(101));
        }

        #endregion

        #region reply parsing (LogsResponse ":MEAS" branch)

        private static LogsResponse Parse(string command, string reply)
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            response.ParseLogResponse(new HardwarePacket(command, true),
                                      new HardwarePacket(reply), // single-arg ctor = a received packet
                                      LogsRequest.LogCommands.GetLogs);
            return response;
        }

        [TestMethod]
        public void ParseLogResponse_ReadsAnNr3MeasurementValue()
        {
            var r = Parse(":MEASure:VPP? CHANnel1", "+1.24000E+00\r\n");

            Assert.AreEqual(1, r.Measurements.Count);
            Assert.AreEqual(1.24, r.Measurements[0], 1e-9);
        }

        [TestMethod]
        public void ParseLogResponse_KeepsTheCannotMeasureSentinelIntactForTheBlToReject()
        {
            var r = Parse(":MEASure:FREQuency? CHANnel1", "+9.9E+37\r\n");

            Assert.AreEqual(1, r.Measurements.Count);
            Assert.IsTrue(KeysightEdux1002aReadings.IsMeasurementError(r.Measurements[0]));
        }

        [TestMethod]
        public void ParseLogResponse_UnparsableReplyIsNotRecordedAsZero()
        {
            // Regression: the old branch added the TryParse out-value unconditionally, so a garbled
            // reply reached the app as a perfectly plausible reading of 0.
            var r = Parse(":MEASure:VPP? CHANnel1", "\r\n");

            Assert.AreEqual(0, r.Measurements.Count);
        }

        #endregion
    }
}
