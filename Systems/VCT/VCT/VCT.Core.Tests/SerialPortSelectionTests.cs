using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Core;
using System.Collections.Generic;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers <see cref="ServerCore.SelectAutoSerialPort"/> — the choice an AUTO serial tunnel makes.
    /// The port names and device strings below are the ones this bench actually reports.
    /// </summary>
    [TestClass]
    public class SerialPortSelectionTests
    {
        private const string Bluetooth7 = "Standard Serial over Bluetooth link (COM7)";
        private const string Bluetooth8 = "Standard Serial over Bluetooth link (COM8)";
        private const string Prolific10 = "Prolific USB-to-Serial Comm Port (COM10)";
        private const string Ftdi4 = "USB Serial Port (COM4)";

        private static List<KeyValuePair<string, string>> Ports(params KeyValuePair<string, string>[] p)
        {
            return new List<KeyValuePair<string, string>>(p);
        }

        private static KeyValuePair<string, string> Port(string name, string device)
        {
            return new KeyValuePair<string, string>(name, device);
        }

        #region the exclusion — the reason this function exists

        [TestMethod]
        public void ClaimedPort_IsNeverSelected()
        {
            // The regression: the keyword list matches "Prolific", so AUTO used to take COM10 — the
            // PRODIGIT 3111's adapter — and open it at its own 9600 instead of the load's 115200.
            var ports = Ports(Port("COM8", Bluetooth8), Port("COM10", Prolific10), Port("COM7", Bluetooth7));

            var selected = ServerCore.SelectAutoSerialPort(ports, new[] { "COM10" });

            Assert.AreNotEqual("COM10", selected);
            Assert.IsNull(selected, "only Bluetooth ports were left, so nothing is suitable");
        }

        [TestMethod]
        public void ClaimedPort_ExclusionIsCaseAndWhitespaceInsensitive()
        {
            var ports = Ports(Port("COM10", Prolific10));

            Assert.IsNull(ServerCore.SelectAutoSerialPort(ports, new[] { "com10" }));
            Assert.IsNull(ServerCore.SelectAutoSerialPort(ports, new[] { "  COM10  " }));
        }

        [TestMethod]
        public void ExcludingOneAdapter_StillSelectsAnother()
        {
            var ports = Ports(Port("COM10", Prolific10), Port("COM4", Ftdi4));

            Assert.AreEqual("COM4", ServerCore.SelectAutoSerialPort(ports, new[] { "COM10" }));
        }

        [TestMethod]
        public void NoExclusions_BehavesAsBefore()
        {
            var ports = Ports(Port("COM8", Bluetooth8), Port("COM10", Prolific10));

            Assert.AreEqual("COM10", ServerCore.SelectAutoSerialPort(ports, null));
            Assert.AreEqual("COM10", ServerCore.SelectAutoSerialPort(ports, new string[0]));
        }

        #endregion

        #region priority order

        [TestMethod]
        public void UsbToSerialAdapter_WinsOverBluetooth_EvenWhenListedLater()
        {
            var ports = Ports(Port("COM8", Bluetooth8), Port("COM7", Bluetooth7), Port("COM10", Prolific10));

            Assert.AreEqual("COM10", ServerCore.SelectAutoSerialPort(ports, null));
        }

        [TestMethod]
        public void EveryKnownAdapterKeywordIsRecognised()
        {
            foreach (var keyword in ServerCore.UsbToSerialKeywords)
            {
                var ports = Ports(Port("COM8", Bluetooth8), Port("COM9", keyword + " Device (COM9)"));
                Assert.AreEqual("COM9", ServerCore.SelectAutoSerialPort(ports, null), "keyword: " + keyword);
            }
        }

        [TestMethod]
        public void WithNoAdapter_FallsBackToTheFirstNonBluetoothPort()
        {
            var ports = Ports(Port("COM8", Bluetooth8), Port("COM3", "Communications Port (COM3)"));

            Assert.AreEqual("COM3", ServerCore.SelectAutoSerialPort(ports, null));
        }

        [TestMethod]
        public void BluetoothOnly_SelectsNothing()
        {
            var ports = Ports(Port("COM8", Bluetooth8), Port("COM7", Bluetooth7));

            Assert.IsNull(ServerCore.SelectAutoSerialPort(ports, null));
        }

        #endregion

        #region degenerate input

        [TestMethod]
        public void EmptyOrNullInput_SelectsNothing()
        {
            Assert.IsNull(ServerCore.SelectAutoSerialPort(null, null));
            Assert.IsNull(ServerCore.SelectAutoSerialPort(Ports(), null));
        }

        [TestMethod]
        public void PortsWithoutANameAreIgnored()
        {
            var ports = Ports(Port("", Prolific10), Port(null, Ftdi4), Port("COM3", "Communications Port (COM3)"));

            Assert.AreEqual("COM3", ServerCore.SelectAutoSerialPort(ports, null));
        }

        [TestMethod]
        public void ANullDeviceNameDoesNotThrow()
        {
            var ports = Ports(Port("COM3", null));

            // Unknown device, but not Bluetooth — the fallback still offers it.
            Assert.AreEqual("COM3", ServerCore.SelectAutoSerialPort(ports, null));
        }

        [TestMethod]
        public void BlankExclusionEntriesAreIgnored()
        {
            var ports = Ports(Port("COM10", Prolific10));

            Assert.AreEqual("COM10", ServerCore.SelectAutoSerialPort(ports, new[] { "", "   ", null }));
        }

        #endregion
    }
}
