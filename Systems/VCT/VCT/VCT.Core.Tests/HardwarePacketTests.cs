using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;

namespace Galcon.VCT.Core.Tests
{
    [TestClass]
    public class HardwarePacketTests
    {
        #region Constructor Tests

        [TestMethod]
        public void Constructor_WithFloatResponse_SetsFloatDataAndCreationDate()
        {
            var before = DateTime.Now;
            var packet = new HardwarePacket(42.5f);
            var after = DateTime.Now;

            Assert.AreEqual(42.5f, packet.FloatData);
            Assert.IsTrue(packet.CreationDate >= before && packet.CreationDate <= after);
            Assert.IsNull(packet.Command);
            Assert.IsNull(packet.Response);
        }

        [TestMethod]
        public void Constructor_WithStringResponse_SetsResponseAndCreationDate()
        {
            var before = DateTime.Now;
            var packet = new HardwarePacket("test response");
            var after = DateTime.Now;

            Assert.AreEqual("test response", packet.Response);
            Assert.IsTrue(packet.CreationDate >= before && packet.CreationDate <= after);
            Assert.IsNull(packet.Command);
        }

        [TestMethod]
        public void Constructor_WithNullStringResponse_SetsResponseToNull()
        {
            var packet = new HardwarePacket((string)null);

            Assert.IsNull(packet.Response);
        }

        [TestMethod]
        public void Constructor_WithEmptyStringResponse_SetsResponseToEmpty()
        {
            var packet = new HardwarePacket("");

            Assert.AreEqual("", packet.Response);
        }

        [TestMethod]
        public void Constructor_WithCommandAndWait_SetsCommandAndWait4Respons()
        {
            var before = DateTime.Now;
            var packet = new HardwarePacket("*IDN?\r\n", true);
            var after = DateTime.Now;

            Assert.AreEqual("*IDN?\r\n", packet.Command);
            Assert.IsTrue(packet.Wait4Respons);
            Assert.IsTrue(packet.CreationDate >= before && packet.CreationDate <= after);
            Assert.IsNull(packet.Response);
        }

        [TestMethod]
        public void Constructor_WithCommandAndNoWait_SetsWait4ResponsFalse()
        {
            var packet = new HardwarePacket("SCAN 1\r\n", false);

            Assert.AreEqual("SCAN 1\r\n", packet.Command);
            Assert.IsFalse(packet.Wait4Respons);
        }

        [TestMethod]
        public void Constructor_WithFloat_ZeroValue()
        {
            var packet = new HardwarePacket(0.0f);

            Assert.AreEqual(0.0f, packet.FloatData);
        }

        [TestMethod]
        public void Constructor_WithFloat_NegativeValue()
        {
            var packet = new HardwarePacket(-273.15f);

            Assert.AreEqual(-273.15f, packet.FloatData);
        }

        #endregion

        #region OK Property Tests

        [TestMethod]
        public void OK_ResponseContainsNewLine_ReturnsTrue()
        {
            var packet = new HardwarePacket("42\r\n");

            Assert.IsTrue(packet.OK);
        }

        [TestMethod]
        public void OK_ResponseWithoutNewLine_ReturnsFalse()
        {
            var packet = new HardwarePacket("some data");

            Assert.IsFalse(packet.OK);
        }

        [TestMethod]
        public void OK_CommandContainsArrow_ReturnsTrue()
        {
            var packet = new HardwarePacket("=>", true);

            Assert.IsTrue(packet.OK);
        }

        [TestMethod]
        public void OK_CommandWithoutArrow_ReturnsFalse()
        {
            var packet = new HardwarePacket("*IDN?\r\n", true);

            // Command contains \r\n but OK checks Command for "=>" specifically
            // Response is null, Command doesn't contain "=>"
            Assert.IsFalse(packet.OK);
        }

        [TestMethod]
        public void OK_NullResponse_NullCommand_ReturnsFalse()
        {
            var packet = new HardwarePacket(0.0f);

            // Both Command and Response are null
            Assert.IsFalse(packet.OK);
        }

        [TestMethod]
        public void OK_ResponseIsEmptyString_ReturnsFalse()
        {
            var packet = new HardwarePacket("");

            Assert.IsFalse(packet.OK);
        }

        [TestMethod]
        public void OK_ResponseContainsOnlyCR_ReturnsFalse()
        {
            var packet = new HardwarePacket("data\r");

            Assert.IsFalse(packet.OK);
        }

        [TestMethod]
        public void OK_ResponseContainsOnlyLF_ReturnsFalse()
        {
            var packet = new HardwarePacket("data\n");

            Assert.IsFalse(packet.OK);
        }

        [TestMethod]
        public void OK_ResponseWithNewLineInMiddle_ReturnsTrue()
        {
            var packet = new HardwarePacket("line1\r\nline2");

            Assert.IsTrue(packet.OK);
        }

        [TestMethod]
        public void OK_CommandWithArrowAndResponseNull_ReturnsTrue()
        {
            var packet = new HardwarePacket("cmd=>done", true);

            Assert.IsTrue(packet.OK);
        }

        #endregion

        #region ToString Tests

        [TestMethod]
        public void ToString_WithResponse_ReturnsResponse()
        {
            var packet = new HardwarePacket("my response");

            Assert.AreEqual("my response", packet.ToString());
        }

        [TestMethod]
        public void ToString_WithNullResponse_ReturnsCommand()
        {
            var packet = new HardwarePacket("my command", false);

            Assert.AreEqual("my command", packet.ToString());
        }

        [TestMethod]
        public void ToString_WithEmptyResponse_ReturnsCommand()
        {
            var packet = new HardwarePacket("", false);

            // Response is null (it's a command constructor), so Command is returned
            Assert.AreEqual("", packet.ToString());
        }

        [TestMethod]
        public void ToString_WithBothNullResponseAndNullCommand_ReturnsNull()
        {
            var packet = new HardwarePacket(0.0f);

            // Both Response and Command are null
            Assert.IsNull(packet.ToString());
        }

        #endregion

        #region ToBytes Tests

        [TestMethod]
        public void ToBytes_WithCommand_ReturnsAsciiBytes()
        {
            var packet = new HardwarePacket("ABC", false);

            byte[] bytes = packet.ToBytes();

            Assert.AreEqual(3, bytes.Length);
            Assert.AreEqual((byte)'A', bytes[0]);
            Assert.AreEqual((byte)'B', bytes[1]);
            Assert.AreEqual((byte)'C', bytes[2]);
        }

        [TestMethod]
        public void ToBytes_WithCommandIncludingNewLine_IncludesNewLineBytes()
        {
            var packet = new HardwarePacket("*RST\r\n", false);

            byte[] bytes = packet.ToBytes();

            Assert.AreEqual(6, bytes.Length);
            Assert.AreEqual((byte)'\r', bytes[4]);
            Assert.AreEqual((byte)'\n', bytes[5]);
        }

        #endregion
    }
}
