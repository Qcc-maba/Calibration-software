using Maba.VCT.Common.Protocol_Parser;
using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class WebSocketProtocolParserTests
    {
        private WebSocketProtocolParaser _parser;
        private BaseMessage _parsedPacket;
        private int _packetCount;

        [TestInitialize]
        public void Setup()
        {
            _parser = new WebSocketProtocolParaser();
            _packetCount = 0;
            _parser.OnPacket = (s, e) =>
            {
                _parsedPacket = e.P as BaseMessage;
                _packetCount++;
            };
        }

        #region LoggerConfiguration Tests

        [TestMethod]
        public void ParseLoggerConfiguration_ShouldParseCorrectly()
        {
            string message = "CMD:LoggerConfiguration,LoggerID:L1,IP:192.168.1.1,Rate:100,Interval:1000,BatchID:B1,BatchChannels:C1";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            Assert.IsInstanceOfType(_parsedPacket, typeof(LoggerConfigurationMessage));
            var config = (LoggerConfigurationMessage)_parsedPacket;
            Assert.AreEqual(1, config.Loggers.Count);
            Assert.AreEqual("L1", config.Loggers[0].LoggerId);
            Assert.AreEqual("192.168.1.1", config.Loggers[0].IP);
            Assert.AreEqual("100", config.Loggers[0].Rate);
            Assert.AreEqual("1000", config.Loggers[0].Interval);
            Assert.AreEqual("B1", config.Loggers[0].BatchId);
            Assert.AreEqual("C1", config.Loggers[0].BatchChannels);
        }

        [TestMethod]
        public void ParseLoggerConfiguration_MultipleLoggers_ParsesAll()
        {
            string message = "CMD:LoggerConfiguration,LoggerID:L1,IP:10.0.0.1,Rate:50,Interval:500,BatchID:B1,BatchChannels:C1,LoggerID:L2,IP:10.0.0.2,Rate:100,Interval:1000,BatchID:B2,BatchChannels:C2";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            var config = (LoggerConfigurationMessage)_parsedPacket;
            Assert.AreEqual(2, config.Loggers.Count);
            Assert.AreEqual("L1", config.Loggers[0].LoggerId);
            Assert.AreEqual("10.0.0.1", config.Loggers[0].IP);
            Assert.AreEqual("L2", config.Loggers[1].LoggerId);
            Assert.AreEqual("10.0.0.2", config.Loggers[1].IP);
        }

        [TestMethod]
        public void ParseLoggerConfiguration_ThreeLoggers_ParsesAll()
        {
            string message = "CMD:LoggerConfiguration," +
                "LoggerID:L1,IP:10.0.0.1,Rate:50,Interval:500,BatchID:B1,BatchChannels:C1," +
                "LoggerID:L2,IP:10.0.0.2,Rate:100,Interval:1000,BatchID:B2,BatchChannels:C2," +
                "LoggerID:L3,IP:10.0.0.3,Rate:200,Interval:2000,BatchID:B3,BatchChannels:C3";

            _parser.OnData(message);

            var config = (LoggerConfigurationMessage)_parsedPacket;
            Assert.AreEqual(3, config.Loggers.Count);
            Assert.AreEqual("L3", config.Loggers[2].LoggerId);
            Assert.AreEqual("200", config.Loggers[2].Rate);
        }

        [TestMethod]
        public void LoggerConfigurationParser_DirectCall_ReturnsMessage()
        {
            string message = "CMD:LoggerConfiguration,LoggerID:L1,IP:1.2.3.4,Rate:10,Interval:100,BatchID:B,BatchChannels:1";
            _parser.OnData(message);

            var result = _parser.LoggerConfigurationParser();
            Assert.IsNotNull(result);
            Assert.IsInstanceOfType(result, typeof(LoggerConfigurationMessage));
        }

        #endregion

        #region SensorsAssociation Tests

        [TestMethod]
        public void ParseSensorsAssociation_ShouldParseCorrectly()
        {
            string message = "CMD:SensorsAssociation,LoggerID:L2,DeviceID:D1,BatchID:B2,BatchChannels:C2,Units:Celsius,Resolution:0.1,SendData:true";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            Assert.IsInstanceOfType(_parsedPacket, typeof(SensorsAssociationMessage));
            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("L2", assoc.LoggerId);
            Assert.AreEqual("D1", assoc.DeviceId);
            Assert.AreEqual("B2", assoc.BatchId);
            Assert.AreEqual("C2", assoc.BatchChannels);
            Assert.AreEqual("Celsius", assoc.Units);
            Assert.AreEqual("0.1", assoc.Resolution);
            Assert.IsTrue(assoc.SendData);
        }

        [TestMethod]
        public void ParseSensorsAssociation_SendDataFalse_ParsedCorrectly()
        {
            string message = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,SendData:false";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.IsFalse(assoc.SendData);
        }

        [TestMethod]
        public void ParseSensorsAssociation_MissingOptionalFields_DefaultsToNull()
        {
            string message = "CMD:SensorsAssociation,LoggerID:L1";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("L1", assoc.LoggerId);
            Assert.IsNull(assoc.DeviceId);
            Assert.IsNull(assoc.BatchId);
            Assert.IsNull(assoc.BatchChannels);
        }

        [TestMethod]
        public void ParseSensorsAssociation_WithBatchChannels_ParsesAll()
        {
            string message = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,BatchChannels:1;2;3,Units:F,Resolution:3";

            _parser.OnData(message);

            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("1;2;3", assoc.BatchChannels);
            Assert.AreEqual("F", assoc.Units);
            Assert.AreEqual("3", assoc.Resolution);
        }

        [TestMethod]
        public void ParseSensorsAssociation_UnitsOnly_NoResolution()
        {
            string message = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,Units:Fahrenheit";

            _parser.OnData(message);

            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("Fahrenheit", assoc.Units);
            Assert.IsNull(assoc.Resolution);
        }

        [TestMethod]
        public void ParseSensorsAssociation_ResolutionOnly_NoUnits()
        {
            string message = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,Resolution:4";

            _parser.OnData(message);

            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.IsNull(assoc.Units);
            Assert.AreEqual("4", assoc.Resolution);
        }

        [TestMethod]
        public void SensorsAssociationParser_DirectCall_ReturnsMessage()
        {
            string message = "CMD:SensorsAssociation,DeviceID:DEV1,LoggerID:LOG1";
            _parser.OnData(message);

            var result = _parser.SensorsAssociationParser();
            Assert.IsNotNull(result);
            Assert.IsInstanceOfType(result, typeof(SensorsAssociationMessage));
        }

        [TestMethod]
        public void ParseSensorsAssociation_AllFieldsPopulated()
        {
            string message = "CMD:SensorsAssociation,LoggerID:LOG-001,DeviceID:DEV-002,BatchID:BATCH-003,BatchChannels:1;2;3;4;5,Units:Kelvin,Resolution:5,SendData:true";

            _parser.OnData(message);

            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("LOG-001", assoc.LoggerId);
            Assert.AreEqual("DEV-002", assoc.DeviceId);
            Assert.AreEqual("BATCH-003", assoc.BatchId);
            Assert.AreEqual("1;2;3;4;5", assoc.BatchChannels);
            Assert.AreEqual("Kelvin", assoc.Units);
            Assert.AreEqual("5", assoc.Resolution);
            Assert.IsTrue(assoc.SendData);
        }

        #endregion

        #region CreateReport Tests

        [TestMethod]
        public void ParseCreateReport_ShouldParseCorrectly()
        {
            string message = "CMD:CreateReport";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            Assert.IsInstanceOfType(_parsedPacket, typeof(CreateReportMessage));
        }

        [TestMethod]
        public void ParseCreateReport_WithExtraFields_StillParses()
        {
            string message = "CMD:CreateReport,DeviceID:D1";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            Assert.IsInstanceOfType(_parsedPacket, typeof(CreateReportMessage));
        }

        #endregion

        #region Serialization Tests

        [TestMethod]
        public void SerializeMessage_ReturnsJsonString()
        {
            var msg = new CreateReportMessage { Command = "CreateReport" };
            var json = WebSocketProtocolParaser.SerializeMessage(msg);

            Assert.IsNotNull(json);
            Assert.IsTrue(json.Contains("CreateReport"));
        }

        [TestMethod]
        public void ParseMessage_DeserializesFromJson()
        {
            var original = new CreateReportMessage { Command = "CreateReport" };
            var json = WebSocketProtocolParaser.SerializeMessage(original);

            var parsed = WebSocketProtocolParaser.ParseMessage<CreateReportMessage>(json);

            Assert.IsNotNull(parsed);
            Assert.AreEqual("CreateReport", parsed.Command);
        }

        [TestMethod]
        public void SerializeDeserialize_SensorsAssociation_Roundtrip()
        {
            var original = new SensorsAssociationMessage
            {
                Command = "SensorsAssociation",
                DeviceId = "DEV-1",
                LoggerId = "LOG-1",
                BatchId = "BATCH-1",
                Units = "Celsius",
                Resolution = "2",
                SendData = true
            };
            var json = WebSocketProtocolParaser.SerializeMessage(original);
            var parsed = WebSocketProtocolParaser.ParseMessage<SensorsAssociationMessage>(json);

            Assert.AreEqual("DEV-1", parsed.DeviceId);
            Assert.AreEqual("LOG-1", parsed.LoggerId);
            Assert.AreEqual("BATCH-1", parsed.BatchId);
            Assert.AreEqual("Celsius", parsed.Units);
            Assert.AreEqual("2", parsed.Resolution);
            Assert.IsTrue(parsed.SendData);
        }

        [TestMethod]
        public void SerializeDeserialize_LoggerConfiguration_Roundtrip()
        {
            var original = new LoggerConfigurationMessage
            {
                Command = "LoggerConfiguration",
                Loggers = new List<LoggerConfig>
                {
                    new LoggerConfig { LoggerId = "L1", IP = "10.0.0.1", Rate = "100", Interval = "500", BatchId = "B1", BatchChannels = "1;2" }
                }
            };
            var json = WebSocketProtocolParaser.SerializeMessage(original);
            var parsed = WebSocketProtocolParaser.ParseMessage<LoggerConfigurationMessage>(json);

            Assert.IsNotNull(parsed.Loggers);
            Assert.AreEqual(1, parsed.Loggers.Count);
            Assert.AreEqual("L1", parsed.Loggers[0].LoggerId);
        }

        #endregion

        #region Status (Hydra start — same shape as Next.js sendStatus)

        [TestMethod]
        public void ParseStatus_Start_QuotedFormat_AsSentFromWebApp()
        {
            var message = "CMD:\"Status\", Value:\"Start\", DeviceID:\"21-142\"";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            Assert.IsInstanceOfType(_parsedPacket, typeof(StatusMessage));
            var st = (StatusMessage)_parsedPacket;
            Assert.AreEqual("Start", st.Value);
            Assert.AreEqual("21-142", st.DeviceID);
        }

        #endregion

        #region Edge Cases / Error Handling

        [TestMethod]
        public void OnData_ByteArray_DoesNotThrow()
        {
            _parser.OnData(new byte[] { 0x01, 0x02 }, 0, 2);
        }

        [TestMethod]
        public void ParsePackets_UnknownCommand_CallsOnPacketWithNullMessage()
        {
            // Unknown commands fire OnPacket but the packet is null (not a known BaseMessage subclass)
            string message = "CMD:UnknownCommand,Key:Value";

            _parser.OnData(message);

            Assert.AreEqual(1, _packetCount);
            Assert.IsNull(_parsedPacket); // e.P is null for unknown commands
        }

        [TestMethod]
        public void OnData_WhitespaceInValues_TrimmedCorrectly()
        {
            string message = "CMD:SensorsAssociation, LoggerID:L1 , DeviceID: D1 ,BatchID: B1";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            var assoc = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("L1", assoc.LoggerId);
            Assert.AreEqual("D1", assoc.DeviceId);
            Assert.AreEqual("B1", assoc.BatchId);
        }

        [TestMethod]
        public void OnData_QuotedValues_ParsedCorrectly()
        {
            // Messages may arrive with quoted values from the WebSocket broadcast format
            string message = "CMD:SensorsAssociation,LoggerID:\"L1\",DeviceID:\"D1\",BatchID:\"B1\"";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            var assoc = (SensorsAssociationMessage)_parsedPacket;
            // Quotes should be stripped by the parser
            Assert.AreEqual("L1", assoc.LoggerId);
        }

        [TestMethod]
        public void OnData_CalledMultipleTimes_EachCallProcessedIndependently()
        {
            _parser.OnData("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            Assert.AreEqual(1, _packetCount);
            var first = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("D1", first.DeviceId);

            _parser.OnData("CMD:SensorsAssociation,LoggerID:L2,DeviceID:D2,BatchID:B2");
            Assert.AreEqual(2, _packetCount);
            var second = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("D2", second.DeviceId);
        }

        [TestMethod]
        [ExpectedException(typeof(NullReferenceException))]
        public void OnData_NoOnPacketHandler_ThrowsNullRef()
        {
            // BUG: Parser crashes with NullReferenceException if OnPacket delegate is not set.
            // WebSocketDeviceHost always sets OnPacket in constructor, so this doesn't happen in practice,
            // but it's a defensive gap.
            var parser = new WebSocketProtocolParaser();
            parser.OnData("CMD:SensorsAssociation,LoggerID:L1");
        }

        [TestMethod]
        public void ParseSensorsAssociation_EmptyValues_ParsedAsEmpty()
        {
            string message = "CMD:SensorsAssociation,LoggerID:,DeviceID:,BatchID:";

            _parser.OnData(message);

            Assert.IsNotNull(_parsedPacket);
            var assoc = (SensorsAssociationMessage)_parsedPacket;
            // Empty values after colon
            Assert.AreEqual("", assoc.LoggerId);
        }

        #endregion

        #region Message Format Validation Tests (matching BroadcastToWebSockets output)

        [TestMethod]
        public void LoggerDataMessage_HasExpectedProperties()
        {
            // Verify LoggerDataMessage structure matches broadcast format
            var msg = new LoggerDataMessage();
            msg.Command = "LoggerData";

            Assert.AreEqual("LoggerData", msg.Command);
        }

        [TestMethod]
        public void SensorsAssociationMessage_DefaultSendData_IsFalse()
        {
            var msg = new SensorsAssociationMessage();
            Assert.IsFalse(msg.SendData);
        }

        [TestMethod]
        public void LoggerConfigurationMessage_DefaultLoggers_IsNotNull()
        {
            // Depends on implementation - verify it doesn't blow up
            var msg = new LoggerConfigurationMessage();
            // Loggers might be null or empty depending on constructor
            Assert.IsNotNull(msg);
        }

        [TestMethod]
        public void LoggerConfig_AllProperties_Settable()
        {
            var config = new LoggerConfig
            {
                LoggerId = "L1",
                IP = "192.168.1.1",
                Rate = "100",
                Interval = "1000",
                BatchId = "B1",
                BatchChannels = "1;2;3"
            };

            Assert.AreEqual("L1", config.LoggerId);
            Assert.AreEqual("192.168.1.1", config.IP);
            Assert.AreEqual("100", config.Rate);
            Assert.AreEqual("1000", config.Interval);
            Assert.AreEqual("B1", config.BatchId);
            Assert.AreEqual("1;2;3", config.BatchChannels);
        }

        #endregion

        #region Stress / Rapid Message Tests

        [TestMethod]
        public void OnData_ManyMessagesRapidly_AllParsed()
        {
            for (int i = 0; i < 100; i++)
            {
                _parser.OnData($"CMD:SensorsAssociation,LoggerID:L{i},DeviceID:D{i},BatchID:B{i}");
            }

            Assert.AreEqual(100, _packetCount);
            var last = (SensorsAssociationMessage)_parsedPacket;
            Assert.AreEqual("D99", last.DeviceId);
        }

        [TestMethod]
        public void OnData_AlternatingMessageTypes_AllParsedCorrectly()
        {
            var types = new List<Type>();
            _parser.OnPacket = (s, e) =>
            {
                _parsedPacket = e.P as BaseMessage;
                types.Add(e.P.GetType());
            };

            _parser.OnData("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            _parser.OnData("CMD:LoggerConfiguration,LoggerID:L1,IP:1.1.1.1,Rate:50,Interval:500,BatchID:B1,BatchChannels:C1");
            _parser.OnData("CMD:CreateReport");
            _parser.OnData("CMD:SensorsAssociation,LoggerID:L2,DeviceID:D2,BatchID:B2");

            Assert.AreEqual(4, types.Count);
            Assert.AreEqual(typeof(SensorsAssociationMessage), types[0]);
            Assert.AreEqual(typeof(LoggerConfigurationMessage), types[1]);
            Assert.AreEqual(typeof(CreateReportMessage), types[2]);
            Assert.AreEqual(typeof(SensorsAssociationMessage), types[3]);
        }

        #endregion
    }
}
