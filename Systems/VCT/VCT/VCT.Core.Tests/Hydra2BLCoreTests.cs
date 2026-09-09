using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class Hydra2BLCoreTests
    {
        private Hydra2BLCore _blCore;

        [TestInitialize]
        public void Setup()
        {
            // Pre-populate the static settings cache to bypass filesystem I/O
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            _blCore = new Hydra2BLCore();
        }

        [TestCleanup]
        public void Cleanup()
        {
            HardwareBL_Settings._settings = null;
        }

        #region Start Tests

        [TestMethod]
        public void Start_SetsVCTServerAndDeviceSettings()
        {
            var server = new ServerCore();
            _blCore.Start(server);

            Assert.AreSame(server, _blCore.VCT_Server);
            Assert.IsNotNull(_blCore.DeviceSettings);
        }

        #endregion

        #region Stop Tests

        [TestMethod]
        public void Stop_DoesNotThrow()
        {
            _blCore.Stop();
        }

        #endregion

        #region OnDeviceConnetion Tests

        [TestMethod]
        public void OnDeviceConnetion_NullDevice_ReturnsFalse()
        {
            var result = _blCore.OnDeviceConnetion(null);
            Assert.IsFalse(result);
        }

        [TestMethod]
        public void OnDeviceConnetion_DeviceNotConnected_ReturnsFalse()
        {
            var comLayer = new MockComLayer();
            comLayer.IsConnected = false;
            var host = new HardwareDeviceHost(new EventsBus(), comLayer, new DeviceSettings());

            var result = _blCore.OnDeviceConnetion(host);
            Assert.IsFalse(result);
        }

        [TestMethod]
        public void OnDeviceConnetion_SNIsNull_ReturnsFalse()
        {
            var comLayer = new MockComLayer();
            var host = new HardwareDeviceHost(new EventsBus(), comLayer, new DeviceSettings());
            // SN is null by default (no identification packet received)

            var result = _blCore.OnDeviceConnetion(host);
            Assert.IsFalse(result);
        }

        [TestMethod]
        public void OnDeviceConnetion_SNNotContaining2625_ReturnsFalse()
        {
            var comLayer = new MockComLayer();
            var bus = new EventsBus();
            var host = new HardwareDeviceHost(bus, comLayer, new DeviceSettings());

            // Identify as a non-2625 device
            var snBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,1234A\r\n");
            comLayer.SimulateDataReceived(snBytes, 0, snBytes.Length);

            var result = _blCore.OnDeviceConnetion(host);
            Assert.IsFalse(result);
        }

        [TestMethod]
        public void OnDeviceConnetion_ValidFluke2625_ReturnsTrue()
        {
            var server = new ServerCore();
            _blCore.Start(server);

            var comLayer = new MockComLayer();
            var bus = new EventsBus();
            var host = new HardwareDeviceHost(bus, comLayer, new DeviceSettings());

            // Identify as Fluke 2625
            var snBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            comLayer.SimulateDataReceived(snBytes, 0, snBytes.Length);

            var result = _blCore.OnDeviceConnetion(host);
            Assert.IsTrue(result);
        }

        [TestMethod]
        public void OnDeviceConnetion_ValidDevice_SetsBLOnDevice()
        {
            var server = new ServerCore();
            _blCore.Start(server);

            var comLayer = new MockComLayer();
            var bus = new EventsBus();
            var host = new HardwareDeviceHost(bus, comLayer, new DeviceSettings());

            var snBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            comLayer.SimulateDataReceived(snBytes, 0, snBytes.Length);

            _blCore.OnDeviceConnetion(host);
            Assert.IsNotNull(host.BL);
        }

        #endregion

        #region OnEvent Tests

        [TestMethod]
        public void OnEvent_BeforeConnection_DoesNotThrow()
        {
            // bl is null before OnDeviceConnetion is called
            var comLayer = new MockComLayer();
            var host = new HardwareDeviceHost(new EventsBus(), comLayer, new DeviceSettings());
            var args = new DeviceEventArgs(host, new Maba.VCT.Common.HardwarePacket("test\r\n"));

            _blCore.OnEvent(args); // Should not throw
        }

        #endregion

        #region OnWebSocketDeviceConnetion Tests

        [TestMethod]
        public void OnWebSocketDeviceConnetion_BeforeConnection_DoesNotThrow()
        {
            var comLayer = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(new EventsBus(), comLayer, "TestWS");

            _blCore.OnWebSocketDeviceConnetion(wsHost); // Should not throw when bl is null
        }

        #endregion
    }
}
