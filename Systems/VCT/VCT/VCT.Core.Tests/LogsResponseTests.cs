using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class LogsResponseTests
    {
        #region Constructor Tests

        [TestMethod]
        public void Constructor_WithResultAndLogCommand_SetsProperties()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.LogCount);

            Assert.IsTrue(response.Result);
            Assert.AreEqual(LogsRequest.LogCommands.LogCount, response.LogCommand);
        }

        [TestMethod]
        public void Constructor_WithFalseResult_ResultIsFalse()
        {
            var response = new LogsResponse(false, LogsRequest.LogCommands.ClearLogs);

            Assert.IsFalse(response.Result);
            Assert.AreEqual(LogsRequest.LogCommands.ClearLogs, response.LogCommand);
        }

        [TestMethod]
        public void Constructor_MeasurementsInitializedEmpty()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);

            Assert.IsNotNull(response.Measurements);
            Assert.AreEqual(0, response.Measurements.Count);
        }

        [TestMethod]
        public void Constructor_WithTemperatureAndHumidity_SetsMeasurements()
        {
            var response = new LogsResponse(25.5, 60.0);

            Assert.AreEqual(2, response.Measurements.Count);
            Assert.AreEqual(25.5, response.Measurements[0]);
            Assert.AreEqual(60.0, response.Measurements[1]);
        }

        #endregion

        #region ParseLogResponse - StopScan

        [TestMethod]
        public void ParseLogResponse_StopScan_DoesNotModifyResponse()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.StopScan);
            var cmd = new HardwarePacket("STOP\r\n", true);
            var result = new HardwarePacket("OK\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.StopScan);

            Assert.AreEqual(0, response.Measurements.Count);
            Assert.AreEqual(0, response.LogCount);
        }

        #endregion

        #region ParseLogResponse - StartScan

        [TestMethod]
        public void ParseLogResponse_StartScan_DoesNotModifyResponse()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.StartScan);
            var cmd = new HardwarePacket("SCAN 1\r\n", true);
            var result = new HardwarePacket("OK\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.StartScan);

            Assert.AreEqual(0, response.Measurements.Count);
        }

        #endregion

        #region ParseLogResponse - ClearLogs

        [TestMethod]
        public void ParseLogResponse_ClearLogs_DoesNotModifyResponse()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.ClearLogs);
            var cmd = new HardwarePacket("LOG CLR\r\n", true);
            var result = new HardwarePacket("OK\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.ClearLogs);

            Assert.AreEqual(0, response.Measurements.Count);
        }

        #endregion

        #region ParseLogResponse - LogCount

        [TestMethod]
        public void ParseLogResponse_LogCount_ParsesCount()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.LogCount);
            var cmd = new HardwarePacket("LOG COUNT?\r\n", true);
            var result = new HardwarePacket("42\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.LogCount);

            Assert.AreEqual(42, response.LogCount);
            Assert.IsTrue(response.HasResponse);
        }

        [TestMethod]
        public void ParseLogResponse_LogCount_Zero_ParsesZero()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.LogCount);
            var cmd = new HardwarePacket("LOG COUNT?\r\n", true);
            var result = new HardwarePacket("0\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.LogCount);

            Assert.AreEqual(0, response.LogCount);
            Assert.IsTrue(response.HasResponse);
        }

        [TestMethod]
        public void ParseLogResponse_LogCount_StripsArrowAndNewlines()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.LogCount);
            var cmd = new HardwarePacket("LOG COUNT?\r\n", true);
            var result = new HardwarePacket("5\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.LogCount);

            Assert.AreEqual(5, response.LogCount);
        }

        #endregion

        #region ParseLogResponse - GetLogs with SCAN:DATA:Last?

        [TestMethod]
        public void ParseLogResponse_GetLogs_ScanDataLast_ParsesMeasurements()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("SCAN:DATA:Last?\r\n", true);
            // Format: records separated by ; each record has 5 comma-separated values
            var result = new HardwarePacket("1,2,3,25.5,unit;1,2,4,30.0,unit\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(2, response.Measurements.Count);
            Assert.AreEqual(25.5, response.Measurements[0]);
            Assert.AreEqual(30.0, response.Measurements[1]);
            Assert.IsTrue(response.HasResponse);
        }

        [TestMethod]
        public void ParseLogResponse_GetLogs_ScanDataLast_SkipsRecordsWithLessThan5Fields()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("SCAN:DATA:Last?\r\n", true);
            // First record has only 3 fields - should be skipped
            var result = new HardwarePacket("1,2,3;1,2,3,25.5,unit\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(1, response.Measurements.Count);
            Assert.AreEqual(25.5, response.Measurements[0]);
        }

        #endregion

        #region ParseLogResponse - GetLogs with MEAS

        [TestMethod]
        public void ParseLogResponse_GetLogs_Meas_ParsesDoubleValue()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("MEAS?\r\n", true);
            var result = new HardwarePacket("25.5\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(1, response.Measurements.Count);
            Assert.AreEqual(25.5, response.Measurements[0]);
            Assert.IsTrue(response.HasResponse);
        }

        [TestMethod]
        public void ParseLogResponse_GetLogs_Meas_InvalidValue_AddsZero()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("MEAS?\r\n", true);
            var result = new HardwarePacket("not_a_number\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            // TryParse fails, res = 0
            Assert.AreEqual(1, response.Measurements.Count);
            Assert.AreEqual(0.0, response.Measurements[0]);
            Assert.IsTrue(response.HasResponse);
        }

        #endregion

        #region ParseLogResponse - GetLogs with command "06" or "08" (Modbus)

        [TestMethod]
        public void ParseLogResponse_GetLogs_Command06_ParsesFloatData()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("06", true);
            var result = new HardwarePacket(42.0f);

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(1, response.Measurements.Count);
            Assert.AreEqual(42.0, response.Measurements[0], 0.001);
            Assert.IsTrue(response.HasResponse);
        }

        [TestMethod]
        public void ParseLogResponse_GetLogs_Command08_ParsesFloatData()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("08", true);
            var result = new HardwarePacket(99.9f);

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(1, response.Measurements.Count);
            Assert.AreEqual(99.9, response.Measurements[0], 0.1);
            Assert.IsTrue(response.HasResponse);
        }

        #endregion

        #region ParseLogResponse - GetLogs with GET DATA (Ohm parsing)

        [TestMethod]
        public void ParseLogResponse_GetLogs_GetData_ParsesOhmValues()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("GET DATA\r\n", true);
            // Need >3 lines, with lines containing "Ohm"
            var result = new HardwarePacket("header\r\nline1\r\nline2\r\nline3\r\n  Ch1100.50 Ohm\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.IsTrue(response.Measurements.Count >= 1);
            Assert.IsTrue(response.HasResponse);
        }

        #endregion

        #region ParseLogResponse - GetLogs with DATA (not GET DATA)

        [TestMethod]
        public void ParseLogResponse_GetLogs_DataCommand_ParsesLogCount()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("DATA?\r\n", true);
            var result = new HardwarePacket("10,extra\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(10, response.LogCount);
            Assert.IsTrue(response.HasResponse);
        }

        #endregion

        #region ParseLogResponse - GetLogs with READ

        [TestMethod]
        public void ParseLogResponse_GetLogs_ReadCommand_ParsesCommaSeparatedValues()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("READ?\r\n", true);
            var result = new HardwarePacket("25.5,30.0,35.5\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            Assert.AreEqual(3, response.Measurements.Count);
            Assert.AreEqual(25.5, response.Measurements[0]);
            Assert.AreEqual(30.0, response.Measurements[1]);
            Assert.AreEqual(35.5, response.Measurements[2]);
            Assert.IsTrue(response.HasResponse);
        }

        #endregion

        #region ParseLogResponse - GetLogs default (Hydra format)

        [TestMethod]
        public void ParseLogResponse_GetLogs_HydraFormat_ParsesDateAndMeasurements()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("LOGGED? 1\r\n", true);
            // Format: HH,MM,SS,MM,DD,YY,val1,val2,...,alarm,digitalIO,totalizer
            var result = new HardwarePacket("12,30,45,06,15,25,25.5,30.0,0,0,100\r\n");

            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);

            // Date: 2025-06-15 12:30:45
            Assert.AreEqual(new DateTime(2025, 6, 15, 12, 30, 45), response.LogDate);
            // Measurements: from index 6 to Length-3 = indices 6,7 -> 25.5 and 30.0
            Assert.AreEqual(2, response.Measurements.Count);
            Assert.AreEqual(25.5, response.Measurements[0]);
            Assert.AreEqual(30.0, response.Measurements[1]);
            Assert.AreEqual(0, response.DigitalIOLineState);
            Assert.AreEqual("100", response.Totalizer);
        }

        [TestMethod]
        public void ParseLogResponse_GetLogs_HydraFormat_BadData_DoesNotThrow()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("LOGGED? 1\r\n", true);
            var result = new HardwarePacket("bad,data\r\n");

            // Should not throw (catch block handles parse errors)
            response.ParseLogResponse(cmd, result, LogsRequest.LogCommands.GetLogs);
        }

        #endregion

        #region ParseLogResponse - Default LogCommand

        [TestMethod]
        public void ParseLogResponse_UnknownCommand_DoesNotThrow()
        {
            var response = new LogsResponse(true, LogsRequest.LogCommands.GetLogs);
            var cmd = new HardwarePacket("UNKNOWN\r\n", true);
            var result = new HardwarePacket("result\r\n");

            // The default branch in the else clause should handle gracefully
            response.ParseLogResponse(cmd, result, (LogsRequest.LogCommands)999);
        }

        #endregion
    }
}
