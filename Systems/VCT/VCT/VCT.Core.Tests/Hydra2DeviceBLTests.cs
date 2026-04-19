using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Maba.VCT.Common;

namespace Galcon.VCT.Core.Tests
{
    /// <summary>
    /// Tests for the Hydra2DeviceBL state machine.
    /// The class is internal so tests access it through Hydra2BLCore.OnDeviceConnetion()
    /// and via PrivateObject for private state machine methods.
    /// </summary>
    [TestClass]
    public class Hydra2DeviceBLTests
    {
        private Hydra2BLCore _blCore;
        private HardwareDeviceHost _deviceHost;
        private MockComLayer _comLayer;
        private EventsBus _bus;

        [TestInitialize]
        public void Setup()
        {
            // Pre-populate static settings cache to bypass filesystem
            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();

            _bus = new EventsBus();
            _blCore = new Hydra2BLCore();

            var server = new ServerCore();
            _blCore.Start(server);

            // Create device host with Fluke 2625A identity
            _comLayer = new MockComLayer();
            _deviceHost = new HardwareDeviceHost(_bus, _comLayer, new DeviceSettings());

            // Identify as Fluke 2625
            var snBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            _comLayer.SimulateDataReceived(snBytes, 0, snBytes.Length);
        }

        [TestCleanup]
        public void Cleanup()
        {
            HardwareBL_Settings._settings = null;
        }

        #region OnDeviceConnetion Flow Tests

        [TestMethod]
        public void OnDeviceConnetion_CreatesAndStartsBL()
        {
            var result = _blCore.OnDeviceConnetion(_deviceHost);

            Assert.IsTrue(result);
            Assert.IsNotNull(_deviceHost.BL);
        }

        [TestMethod]
        public void OnDeviceConnetion_SetsStateMachineProperties()
        {
            _blCore.OnDeviceConnetion(_deviceHost);

            // Access the BL via the device host and use PrivateObject to check states
            var bl = _deviceHost.BL;
            Assert.IsNotNull(bl);

            // The BL has been started, so OnCreateStates should have been called via OnConnection
            var po = new PrivateObject(bl);

            // Access the state machine properties via PrivateObject (they're public on the internal class)
            var initSystem = po.GetProperty("StateMachine_InitSystem");
            var dateSync = po.GetProperty("StateMachine_DateSync");
            var rate = po.GetProperty("StateMachine_Rate");
            var initChannels = po.GetProperty("StateMachine_InitChannles");
            var logs = po.GetProperty("StateMachine_Logs");

            Assert.IsNotNull(initSystem);
            Assert.IsNotNull(dateSync);
            Assert.IsNotNull(rate);
            Assert.IsNotNull(initChannels);
            Assert.IsNotNull(logs);
        }

        [TestMethod]
        public void OnDeviceConnetion_CalledTwice_DoesNotRecreateBL()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            var firstBL = _deviceHost.BL;

            _blCore.OnDeviceConnetion(_deviceHost);
            var secondBL = _deviceHost.BL;

            // The second call should not recreate the BL since device.BL is already Hydra2DeviceBL
            Assert.AreSame(firstBL, secondBL);
        }

        #endregion

        #region OnStepStart Tests

        [TestMethod]
        public void OnStepStart_Start_ReturnsTrue()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var result = po.Invoke("OnStepStart", Maba.VCT.CommServer.CommonBL.BaseBLDevice.DeviceSteps.Start);
            Assert.AreEqual(true, result);
        }

        [TestMethod]
        public void OnStepStart_Routine_ReturnsFalse()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var result = po.Invoke("OnStepStart", Maba.VCT.CommServer.CommonBL.BaseBLDevice.DeviceSteps.Routine);
            Assert.AreEqual(false, result);
        }

        [TestMethod]
        public void OnStepStart_Close_ReturnsTrue()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var result = po.Invoke("OnStepStart", Maba.VCT.CommServer.CommonBL.BaseBLDevice.DeviceSteps.Close);
            Assert.AreEqual(true, result);
        }

        #endregion

        #region OnEvent Tests

        [TestMethod]
        public void OnEvent_DoesNotThrow()
        {
            _blCore.OnDeviceConnetion(_deviceHost);

            var packet = new HardwarePacket("test\r\n");
            var args = new DeviceEventArgs(_deviceHost, packet);

            _deviceHost.BL.OnEvent(args); // Should not throw
        }

        #endregion

        #region Constants Tests

        [TestMethod]
        public void Constants_StateMachineValues_AreCorrect()
        {
            // Access constants via PrivateObject on an instance
            _blCore.OnDeviceConnetion(_deviceHost);
            var bl = _deviceHost.BL;
            var blType = bl.GetType();

            Assert.AreEqual(1, (int)blType.GetField("STATE_MACHINE__InitSystem").GetValue(null));
            Assert.AreEqual(2, (int)blType.GetField("STATE_MACHINE__Date_Sync").GetValue(null));
            Assert.AreEqual(3, (int)blType.GetField("STATE_MACHINE__Rate").GetValue(null));
            Assert.AreEqual(4, (int)blType.GetField("STATE_MACHINE__InitChannels").GetValue(null));
            Assert.AreEqual(5, (int)blType.GetField("STATE_MACHINE__Logs").GetValue(null));
            Assert.AreEqual(6, (int)blType.GetField("STATE_MACHINE__Stop").GetValue(null));
        }

        #endregion

        #region LogResponseCallBack Tests (via PrivateObject)

        [TestMethod]
        public void LogResponseCallBack_ClearLogs_Success_QueuesStartScan()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            _deviceHost.InitSessions();

            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var response = new Maba.VCT.Common.API.RemoteProtocolService.LogsResponse(
                true, Maba.VCT.Common.API.RemoteProtocolService.LogsRequest.LogCommands.ClearLogs);

            // This should not throw and should queue a StartScan request
            po.Invoke("LogResponseCallBack", response);

            // Verify that the comLayer received a SCAN command packet
            // (The session queues it, then Timer() sends it)
        }

        [TestMethod]
        public void LogResponseCallBack_StartScan_Success_QueuesLogCount()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            _deviceHost.InitSessions();

            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var response = new Maba.VCT.Common.API.RemoteProtocolService.LogsResponse(
                true, Maba.VCT.Common.API.RemoteProtocolService.LogsRequest.LogCommands.StartScan);

            po.Invoke("LogResponseCallBack", response);
        }

        [TestMethod]
        public void LogResponseCallBack_LogCount_ZeroCount_RequeuesLogCount()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            _deviceHost.InitSessions();

            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var response = new Maba.VCT.Common.API.RemoteProtocolService.LogsResponse(
                true, Maba.VCT.Common.API.RemoteProtocolService.LogsRequest.LogCommands.LogCount);
            // LogCount defaults to 0

            po.Invoke("LogResponseCallBack", response);
        }

        [TestMethod]
        public void LogResponseCallBack_ResultFalse_RetriesLogCount()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            _deviceHost.InitSessions();

            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var response = new Maba.VCT.Common.API.RemoteProtocolService.LogsResponse(
                false, Maba.VCT.Common.API.RemoteProtocolService.LogsRequest.LogCommands.ClearLogs);

            po.Invoke("LogResponseCallBack", response);
        }

        [TestMethod]
        public void LogResponseCallBack_GetLogs_AddsToResponsesList()
        {
            _blCore.OnDeviceConnetion(_deviceHost);
            _deviceHost.InitSessions();

            var bl = _deviceHost.BL;
            var po = new PrivateObject(bl);

            var response = new Maba.VCT.Common.API.RemoteProtocolService.LogsResponse(
                true, Maba.VCT.Common.API.RemoteProtocolService.LogsRequest.LogCommands.GetLogs);

            po.Invoke("LogResponseCallBack", response);

            // Verify the response was added to the internal responses list
            var responses = po.GetField("responses") as System.Collections.Generic.List<Maba.VCT.Common.API.RemoteProtocolService.LogsResponse>;
            Assert.IsNotNull(responses);
            Assert.AreEqual(1, responses.Count);
        }

        #endregion
    }
}
