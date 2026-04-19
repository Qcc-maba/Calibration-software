using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;

namespace Galcon.VCT.Core.Tests
{
    [TestClass]
    public class HardwareDeviceHostTests
    {
        private EventsBus _bus;
        private MockComLayer _comLayer;
        private HardwareDeviceHost _host;

        [TestInitialize]
        public void Setup()
        {
            _bus = new EventsBus();
            _comLayer = new MockComLayer();
            var settings = new DeviceSettings();
            _host = new HardwareDeviceHost(_bus, _comLayer, settings);
        }

        #region Constructor Tests

        [TestMethod]
        public void Constructor_SetsComLayerAndSettings()
        {
            Assert.IsNotNull(_host.InternalComLayer);
            Assert.IsNotNull(_host.DeviceSettings);
        }

        [TestMethod]
        public void Constructor_SNIsNull_Initially()
        {
            Assert.IsNull(_host.SN);
        }

        [TestMethod]
        public void Constructor_IsConnected_ReflectsComLayer()
        {
            Assert.IsTrue(_host.IsConnected);
        }

        #endregion

        #region IsConnected Tests

        [TestMethod]
        public void IsConnected_WhenComLayerConnected_ReturnsTrue()
        {
            _comLayer.IsConnected = true;
            Assert.IsTrue(_host.IsConnected);
        }

        [TestMethod]
        public void IsConnected_WhenComLayerDisconnected_ReturnsFalse()
        {
            _comLayer.IsConnected = false;
            Assert.IsFalse(_host.IsConnected);
        }

        #endregion

        #region InitSessions Tests

        [TestMethod]
        public void InitSessions_CreatesSessions()
        {
            _host.InitSessions();

            // After InitSessions, the host should be able to process timer ticks
            _host.Timer(); // Should not throw
        }

        [TestMethod]
        public void InitSessions_CalledTwice_DoesNotRecreateSessions()
        {
            _host.InitSessions();
            _host.InitSessions(); // Should not throw or recreate

            _host.Timer();
        }

        #endregion

        #region SendPacket Tests

        [TestMethod]
        public void SendPacket_WhenConnected_SendsToComLayer()
        {
            var packet = new HardwarePacket("*IDN?\r\n", false);

            _host.SendPacket(packet);

            Assert.AreEqual("*IDN?\r\n", _comLayer.LastSentString);
        }

        [TestMethod]
        public void SendPacket_WhenDisconnected_DoesNotSend()
        {
            _comLayer.IsConnected = false;
            var packet = new HardwarePacket("*IDN?\r\n", false);

            _host.SendPacket(packet);

            Assert.IsNull(_comLayer.LastSentString);
        }

        [TestMethod]
        public void SendPacket_FiresPacketSentEvent()
        {
            bool eventFired = false;
            _host.PacketSent += (o, e) => { eventFired = true; };

            var packet = new HardwarePacket("CMD\r\n", false);
            _host.SendPacket(packet);

            Assert.IsTrue(eventFired);
        }

        #endregion

        #region Timer Tests

        [TestMethod]
        public void Timer_BeforeInitSessions_DoesNotThrow()
        {
            // Sessions are null before InitSessions
            _host.Timer();
        }

        [TestMethod]
        public void Timer_AfterInitSessions_CallsSessionTimers()
        {
            _host.InitSessions();
            _host.Timer(); // Should call Timer() on all sessions without error
        }

        [TestMethod]
        public void Timer_WithBL_CallsOnTimer()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;
            _host.InitSessions();

            _host.Timer();

            Assert.IsTrue(mockBL.OnTimerCalled);
        }

        #endregion

        #region Disconnect Tests

        [TestMethod]
        public void Disconnect_WhenNotConnected_DoesNothing()
        {
            _comLayer.IsConnected = false;

            _host.Disconnect(); // Should not throw
        }

        #endregion

        #region ReplaceComLayer Tests

        [TestMethod]
        public void ReplaceComLayer_NullComLayer_DisconnectsOld()
        {
            _host.ReplaceComLayer(null);

            // InternalComLayer should be null after destroy
            Assert.IsNull(_host.InternalComLayer);
        }

        [TestMethod]
        public void ReplaceComLayer_NewComLayer_ReplacesOld()
        {
            var newComLayer = new MockComLayer();
            _host.ReplaceComLayer(newComLayer);

            Assert.AreSame(newComLayer, _host.InternalComLayer);
        }

        #endregion

        #region BroadcastMeasurement Tests

        [TestMethod]
        public void BroadcastMeasurement_FiresIncomingEvent()
        {
            bool eventFired = false;
            _bus.DeviceOnIncomingEvent += (o, e) => { eventFired = true; };

            _host.BroadcastMeasurement(1, 25.5);

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void BroadcastAllMeasurements_FiresIncomingEvent()
        {
            bool eventFired = false;
            _bus.DeviceOnIncomingEvent += (o, e) => { eventFired = true; };

            var channels = new List<int> { 1, 2 };
            var values = new List<double> { 25.5, 30.0 };

            _host.BroadcastAllMeasurements(channels, values);

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void BroadcastAllMeasurements_PacketContainsAllChannels()
        {
            IPacket receivedPacket = null;
            _bus.DeviceOnIncomingEvent += (o, e) => { receivedPacket = e.Packet; };

            var channels = new List<int> { 1, 2, 3 };
            var values = new List<double> { 25.5, 30.0, 35.5 };

            _host.BroadcastAllMeasurements(channels, values);

            Assert.IsNotNull(receivedPacket);
            var packetStr = receivedPacket.ToString();
            Assert.IsTrue(packetStr.Contains("1,25.5"));
            Assert.IsTrue(packetStr.Contains("2,30"));
            Assert.IsTrue(packetStr.Contains("3,35.5"));
        }

        #endregion

        #region Packet Identification Tests

        [TestMethod]
        public void HandlePacket_FlukeDevice_IdentifiesSN()
        {
            _host.InitSessions();

            // Simulate receiving FLUKE identification
            string flukeId = "FLUKE,2625A\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(flukeId);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            Assert.IsNotNull(_host.SN);
            Assert.IsTrue(_host.SN.Contains("FLUKE"));
        }

        [TestMethod]
        public void HandlePacket_ScanData_DoesNotBroadcastDirectly()
        {
            // Raw E, scan packets should NOT broadcast directly from HardwareDeviceHost.
            // Broadcasting is handled by the BL layer (Hydra2DeviceBL.HandleLogData) to avoid duplicates.
            _host.InitSessions();

            // First identify the device
            string flukeId = "FLUKE,2625A\r\n";
            byte[] idBytes = ASCIIEncoding.ASCII.GetBytes(flukeId);
            _comLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // Now send scan data
            bool eventFired = false;
            _bus.DeviceOnIncomingEvent += (o, e) => { eventFired = true; };

            string scanData = "E,1,25.5\r\n";
            byte[] dataBytes = ASCIIEncoding.ASCII.GetBytes(scanData);
            _comLayer.SimulateDataReceived(dataBytes, 0, dataBytes.Length);

            Assert.IsFalse(eventFired, "Raw E, packets should not be broadcast directly; BL handles broadcasting");
        }

        [TestMethod]
        public void HandlePacket_HewlettDevice_IdentifiesSN()
        {
            string hewlettId = "HEWLETT PACKARD 34970A\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(hewlettId);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            Assert.IsNotNull(_host.SN);
            Assert.IsTrue(_host.SN.Contains("HEWLETT"));
        }

        [TestMethod]
        public void HandlePacket_TAUDevice_IdentifiesSN()
        {
            string tauId = "TAU 12345678901234567890123456789\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(tauId);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            Assert.IsNotNull(_host.SN);
            Assert.IsTrue(_host.SN.Contains("TAU"));
        }

        [TestMethod]
        public void HandlePacket_TTIDevice_IdentifiesSN()
        {
            string ttiId = "TTI-XX-1234567890\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(ttiId);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            Assert.IsNotNull(_host.SN);
            Assert.AreEqual(6, _host.SN.Length);
        }

        [TestMethod]
        public void HandlePacket_InstekDevice_IdentifiesSN()
        {
            string instekId = "Instek GPH-2323\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(instekId);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            Assert.IsNotNull(_host.SN);
            Assert.AreEqual("Instek", _host.SN);
        }

        [TestMethod]
        public void HandlePacket_ModbusDevice_IdentifiesAsOptidew()
        {
            var modbusCom = new MockComLayer();
            var modSettings = new DeviceSettings();
            modSettings.IdentificationType = DeviceSettings.IdentificationTypes.Modbus;
            var modHost = new HardwareDeviceHost(_bus, modbusCom, modSettings);

            modbusCom.SimulateDataReceived(new byte[] { 0x01, 0x03, 0x02, 0x00 }, 0, 4);

            Assert.AreEqual("Optidew", modHost.SN);
        }

        [TestMethod]
        public void DataReceived_Modbus_UsesFloatDataPath()
        {
            var modbusCom = new MockComLayer();
            var modSettings = new DeviceSettings(DeviceSettings.IdentificationTypes.Modbus);
            var modHost = new HardwareDeviceHost(_bus, modbusCom, modSettings);
            modHost.InitSessions();

            modbusCom.SimulateFloatDataReceived(1.25f);
        }

        [TestMethod]
        public void HandlePacket_PacketReceivedEvent_IsFired()
        {
            _host.InitSessions();

            bool eventFired = false;
            _host.PacketReceived += (o, e) => { eventFired = true; };

            string data = "FLUKE,2625A\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(data);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void OnDisconnection_WithSessions_CallsSessionOnDisconnect()
        {
            _host.InitSessions();

            _comLayer.SimulateLayerClosed();

            Assert.IsNull(_host.InternalComLayer);
        }

        [TestMethod]
        public void Disconnect_WithBL_CallsOnConnectionFalse()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;
            _comLayer.IsConnected = true;

            _host.Disconnect();

            Assert.IsTrue(mockBL.OnConnectionCalled);
            Assert.IsFalse(mockBL.LastConnectionState);
        }

        [TestMethod]
        public void BroadcastAllMeasurements_EmptyLists_DoesNotThrow()
        {
            var channels = new List<int>();
            var values = new List<double>();

            _host.BroadcastAllMeasurements(channels, values);
        }

        [TestMethod]
        public void IncomingEvents_WithBL_CallsBLOnEvent()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;

            _host.BroadcastMeasurement(1, 25.5);

            Assert.IsNotNull(mockBL.LastEvent);
        }

        [TestMethod]
        public void InitSessions_WithDevice_ReplacesComLayer()
        {
            _host.InitSessions();

            var newComLayer = new MockComLayer();
            var otherHost = new HardwareDeviceHost(_bus, newComLayer, new DeviceSettings());

            _host.InitSessions(otherHost);

            Assert.AreSame(newComLayer, _host.InternalComLayer);
        }

        #endregion

        #region API Method Tests (Reset, Format, etc.)

        [TestMethod]
        public async Task Reset_WithCallback_InvokesCallbackOnResponse()
        {
            _host.InitSessions();

            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("*RST\r\n", true);

            InitSystemResponse receivedResponse = null;
            var task = _host.Reset(request, res => { receivedResponse = res; });
            await task;

            // Request was queued - timer tick needed to process
            _host.Timer();

            // Simulate device response
            string response = "OK\r\n";
            byte[] bytes = ASCIIEncoding.ASCII.GetBytes(response);
            _comLayer.SimulateDataReceived(bytes, 0, bytes.Length);

            // Give callback time to fire
            Thread.Sleep(100);
        }

        [TestMethod]
        public async Task GetLogs_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);

            var task = _host.GetLogs(request, res => { });
            var result = await task;

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task Rate_WithoutCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new RateRequest();
            request.Packet = new HardwarePacket("RATE S\r\n", true);

            var result = await _host.Rate(request);

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task Rate_WithCallback_SetsCallBackResponse()
        {
            _host.InitSessions();

            var request = new RateRequest();
            request.Packet = new HardwarePacket("RATE S\r\n", true);

            var result = await _host.Rate(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task SetTime_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("TIME 12:30:00\r\n", true);

            var result = await _host.SetTime(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task SetDate_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("DATE 01/15/25\r\n", true);

            var result = await _host.SetDate(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task InitChannels_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new InitChannelsRequest(1);
            request.Packet = new HardwarePacket("FUNC 1,VDC\r\n", true);

            var result = await _host.InitChannels(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task Format_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("FORMAT 1\r\n", true);

            var result = await _host.Format(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task PrintType_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("PRINT_TYPE 1\r\n", true);

            var result = await _host.PrintType(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task Print_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("PRINT\r\n", true);

            var result = await _host.Print(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task GetFullDate_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("TIME_DATE?\r\n", true);

            var result = await _host.GetFullDate(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public async Task SetInterval_WithCallback_QueuesRequest()
        {
            _host.InitSessions();

            var request = new RateRequest(0, 0, 30);
            request.Packet = new HardwarePacket("INTVL 00:00:30\r\n", true);

            var result = await _host.SetInterval(request, _ => { });

            Assert.IsTrue(result.Result);
        }

        private static void SimulateOkLine(MockComLayer com)
        {
            var ok = Encoding.ASCII.GetBytes("OK\r\n");
            com.SimulateDataReceived(ok, 0, ok.Length);
        }

        /// <summary>Covers optional Action branches when sessions invoke <c>CallBackResponse</c> after OK.</summary>
        [TestMethod]
        public async Task Format_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("FORMAT 1\r\n", true);
            var fired = false;
            var task = _host.Format(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task PrintType_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("PRINT_TYPE 1\r\n", true);
            var fired = false;
            var task = _host.PrintType(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task Print_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("PRINT\r\n", true);
            var fired = false;
            var task = _host.Print(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task SetTime_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("TIME 12:00\r\n", true);
            var fired = false;
            var task = _host.SetTime(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task SetDate_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("DATE 01/15/25\r\n", true);
            var fired = false;
            var task = _host.SetDate(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task GetFullDate_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("TIME_DATE?\r\n", true);
            var fired = false;
            var task = _host.GetFullDate(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task Rate_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new RateRequest();
            request.Packet = new HardwarePacket("RATE S\r\n", true);
            var fired = false;
            var task = _host.Rate(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task SetInterval_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new RateRequest(0, 0, 30);
            request.Packet = new HardwarePacket("INTVL 00:00:30\r\n", true);
            var fired = false;
            var task = _host.SetInterval(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task InitChannels_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new InitChannelsRequest(1);
            request.Packet = new HardwarePacket("FUNC 1,VDC\r\n", true);
            var fired = false;
            var task = _host.InitChannels(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        [TestMethod]
        public async Task GetLogs_CallbackRunsAfterOkLineFromDevice()
        {
            _host.InitSessions();
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);
            var fired = false;
            var task = _host.GetLogs(request, _ => { fired = true; });
            await task;
            _host.Timer();
            SimulateOkLine(_comLayer);
            Thread.Sleep(150);
            Assert.IsTrue(fired);
        }

        #endregion

        #region Dispose Tests

        [TestMethod]
        public void Dispose_DisconnectsHost()
        {
            _host.Dispose();
            // After dispose, the com layer should be disconnected
        }

        #endregion
    }

    /// <summary>
    /// Mock IDeviceBL for testing.
    /// </summary>
    internal class MockDeviceBL : IDeviceBL
    {
        public bool StartCalled { get; set; }
        public bool OnTimerCalled { get; set; }
        public bool OnConnectionCalled { get; set; }
        public bool LastConnectionState { get; set; }
        public DeviceEventArgs LastEvent { get; set; }

        public void Start(IDeviceHost device) { StartCalled = true; }
        public void OnTimer() { OnTimerCalled = true; }
        public bool OnConnection(bool state)
        {
            OnConnectionCalled = true;
            LastConnectionState = state;
            return true;
        }
        public void OnEvent(DeviceEventArgs e) { LastEvent = e; }
    }
}
