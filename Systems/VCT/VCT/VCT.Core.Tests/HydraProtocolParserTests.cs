using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;

namespace Galcon.VCT.Core.Tests
{
    [TestClass]
    public class HydraProtocolParserTests
    {
        private HydraProtocolParser _parser;
        private List<HardwarePacket> _receivedPackets;

        [TestInitialize]
        public void Setup()
        {
            _parser = new HydraProtocolParser();
            _receivedPackets = new List<HardwarePacket>();
            _parser.OnPacket = (s, e) =>
            {
                _receivedPackets.Add(e.P as HardwarePacket);
            };
        }

        #region OnData(byte[], int, int) Tests

        [TestMethod]
        public void OnData_ArrowTerminator_EmitsPacketWithContentBeforeArrow()
        {
            string data = "some data=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("some data", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_NewLineTerminator_EmitsPacketWithContentIncludingNewLine()
        {
            string data = "42\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("42\r\n", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_ArrowTakesPriorityOverNewLine()
        {
            // If both terminators exist, "=>" should be found first
            string data = "data\r\n=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            // "=>" at index 6, "\r\n" at index 4
            // Arrow is at higher index, but \r\n is at lower index...
            // Actually: IndexOf("=>") returns 6, IndexOf("\r\n") returns 4
            // Since "=>" check comes first (promptIdx >= 0 is checked first even though its at index 6), let's verify
            // Actually, promptIdx = 6 >= 0 is true, so => branch is taken
            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("data\r\n", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_IncompleteData_WaitsForMore()
        {
            string data = "partial";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(0, _receivedPackets.Count);
        }

        [TestMethod]
        public void OnData_IncompleteDataThenComplete_EmitsPacketOnCompletion()
        {
            string part1 = "partial";
            string part2 = " data=>";
            byte[] bytes1 = ASCIIEncoding.ASCII.GetBytes(part1);
            byte[] bytes2 = ASCIIEncoding.ASCII.GetBytes(part2);

            _parser.OnData(bytes1, 0, bytes1.Length);
            Assert.AreEqual(0, _receivedPackets.Count);

            _parser.OnData(bytes2, 0, bytes2.Length);
            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("partial data", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_MultiplePacketsInOneBuffer_EmitsAll()
        {
            string data = "first=>second=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(2, _receivedPackets.Count);
            Assert.AreEqual("first", _receivedPackets[0].Response);
            Assert.AreEqual("second", _receivedPackets[1].Response);
        }

        [TestMethod]
        public void OnData_MultipleNewLinePackets_EmitsAll()
        {
            string data = "line1\r\nline2\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(2, _receivedPackets.Count);
            Assert.AreEqual("line1\r\n", _receivedPackets[0].Response);
            Assert.AreEqual("line2\r\n", _receivedPackets[1].Response);
        }

        [TestMethod]
        public void OnData_MixedTerminators_ParsesCorrectly()
        {
            // Arrow followed by newline data
            string data = "cmd response=>E,SN,1,25.5\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(2, _receivedPackets.Count);
            Assert.AreEqual("cmd response", _receivedPackets[0].Response);
            Assert.AreEqual("E,SN,1,25.5\r\n", _receivedPackets[1].Response);
        }

        [TestMethod]
        public void OnData_EmptyBeforeArrow_EmitsEmptyResponse()
        {
            string data = "=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_EmptyBeforeNewLine_EmitsNewLineOnlyResponse()
        {
            string data = "\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("\r\n", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_WithOffset_ReadsFromOffset()
        {
            string data = "XXXdata=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            // Pass with offset 3
            _parser.OnData(bytes, 3, bytes.Length - 3);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("data", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_PacketCreatedAsHardwarePacket_HasResponseProperty()
        {
            string data = "FLUKE,2625A\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.IsNotNull(_receivedPackets[0]);
            Assert.IsTrue(_receivedPackets[0].OK); // Contains \r\n
        }

        [TestMethod]
        public void OnData_ArrowResponseDoesNotContainNewLine_PacketOKIsFalse()
        {
            string data = "ready=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            // Response = "ready" which doesn't contain \r\n, and it's a Response (not Command) so OK = false
            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.IsFalse(_receivedPackets[0].OK);
        }

        [TestMethod]
        public void OnData_ArrowResponseContainsNewLine_PacketOKIsTrue()
        {
            string data = "data\r\n=>";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            // Response = "data\r\n" which contains Environment.NewLine => OK = true
            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.IsTrue(_receivedPackets[0].OK);
        }

        [TestMethod]
        public void OnData_LargeBufferMultipleChunks_AccumulatesAndParses()
        {
            // Simulate receiving data in multiple small chunks
            string fullData = "response data=>";
            for (int i = 0; i < fullData.Length; i++)
            {
                byte[] singleByte = ASCIIEncoding.ASCII.GetBytes(fullData.Substring(i, 1));
                _parser.OnData(singleByte, 0, 1);
            }

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("response data", _receivedPackets[0].Response);
        }

        [TestMethod]
        public void OnData_TrailingDataAfterLastPacket_RemainsInBuffer()
        {
            string data = "first=>partial";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);

            _parser.OnData(bytes, 0, bytes.Length);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual("first", _receivedPackets[0].Response);

            // Now complete the partial
            string rest = " data=>";
            byte[] restBytes = ASCIIEncoding.ASCII.GetBytes(rest);
            _parser.OnData(restBytes, 0, restBytes.Length);

            Assert.AreEqual(2, _receivedPackets.Count);
            Assert.AreEqual("partial data", _receivedPackets[1].Response);
        }

        #endregion

        #region OnData(float) Tests

        [TestMethod]
        public void OnDataFloat_EmitsPacketWithFloatData()
        {
            _parser.OnData(25.5f);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual(25.5f, _receivedPackets[0].FloatData);
        }

        [TestMethod]
        public void OnDataFloat_ZeroValue_EmitsPacket()
        {
            _parser.OnData(0.0f);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual(0.0f, _receivedPackets[0].FloatData);
        }

        [TestMethod]
        public void OnDataFloat_NegativeValue_EmitsPacket()
        {
            _parser.OnData(-100.0f);

            Assert.AreEqual(1, _receivedPackets.Count);
            Assert.AreEqual(-100.0f, _receivedPackets[0].FloatData);
        }

        #endregion

        #region Locate Tests

        [TestMethod]
        public void Locate_PatternFound_ReturnsTrue()
        {
            byte[] data = new byte[] { 0x01, 0x02, 0x03, 0x04 };
            byte[] pattern = new byte[] { 0x02, 0x03 };

            Assert.IsTrue(HydraProtocolParser.Locate(data, pattern));
        }

        [TestMethod]
        public void Locate_PatternNotFound_ReturnsFalse()
        {
            byte[] data = new byte[] { 0x01, 0x02, 0x03, 0x04 };
            byte[] pattern = new byte[] { 0x05, 0x06 };

            Assert.IsFalse(HydraProtocolParser.Locate(data, pattern));
        }

        [TestMethod]
        public void Locate_NullArray_ReturnsFalse()
        {
            Assert.IsFalse(HydraProtocolParser.Locate(null, new byte[] { 0x01 }));
        }

        [TestMethod]
        public void Locate_NullCandidate_ReturnsFalse()
        {
            Assert.IsFalse(HydraProtocolParser.Locate(new byte[] { 0x01 }, null));
        }

        [TestMethod]
        public void Locate_EmptyArray_ReturnsFalse()
        {
            Assert.IsFalse(HydraProtocolParser.Locate(new byte[0], new byte[] { 0x01 }));
        }

        [TestMethod]
        public void Locate_EmptyCandidate_ReturnsFalse()
        {
            Assert.IsFalse(HydraProtocolParser.Locate(new byte[] { 0x01 }, new byte[0]));
        }

        [TestMethod]
        public void Locate_AllZeroArray_ReturnsFalse()
        {
            Assert.IsFalse(HydraProtocolParser.Locate(new byte[] { 0x00, 0x00 }, new byte[] { 0x01 }));
        }

        [TestMethod]
        public void Locate_AllZeroCandidate_ReturnsFalse()
        {
            Assert.IsFalse(HydraProtocolParser.Locate(new byte[] { 0x01 }, new byte[] { 0x00, 0x00 }));
        }

        [TestMethod]
        public void Locate_CandidateLongerThanArray_ReturnsFalse()
        {
            byte[] data = new byte[] { 0x01 };
            byte[] pattern = new byte[] { 0x01, 0x02 };

            Assert.IsFalse(HydraProtocolParser.Locate(data, pattern));
        }

        [TestMethod]
        public void Locate_PatternAtStart_ReturnsTrue()
        {
            byte[] data = new byte[] { 0x01, 0x02, 0x03 };
            byte[] pattern = new byte[] { 0x01, 0x02 };

            Assert.IsTrue(HydraProtocolParser.Locate(data, pattern));
        }

        [TestMethod]
        public void Locate_PatternAtEnd_ReturnsTrue()
        {
            byte[] data = new byte[] { 0x01, 0x02, 0x03 };
            byte[] pattern = new byte[] { 0x02, 0x03 };

            Assert.IsTrue(HydraProtocolParser.Locate(data, pattern));
        }

        [TestMethod]
        public void Locate_ExactMatch_ReturnsTrue()
        {
            byte[] data = new byte[] { 0x01, 0x02 };
            byte[] pattern = new byte[] { 0x01, 0x02 };

            Assert.IsTrue(HydraProtocolParser.Locate(data, pattern));
        }

        [TestMethod]
        public void Locate_SingleByteMatch_ReturnsTrue()
        {
            byte[] data = new byte[] { 0x01, 0x02, 0x03 };
            byte[] pattern = new byte[] { 0x02 };

            Assert.IsTrue(HydraProtocolParser.Locate(data, pattern));
        }

        #endregion
    }
}
