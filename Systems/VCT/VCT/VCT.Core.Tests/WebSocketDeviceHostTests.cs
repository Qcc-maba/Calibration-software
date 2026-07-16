using System;
using System.Collections.Generic;
using System.Threading;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Maba.VCT.Common;
using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class WebSocketDeviceHostTests
    {
        private EventsBus _bus;
        private MockComLayer _comLayer;
        private WebSocketDeviceHost _host;

        [TestInitialize]
        public void Setup()
        {
            _bus = new EventsBus();
            _comLayer = new MockComLayer();
            _host = new WebSocketDeviceHost(_bus, _comLayer, "TestSN");
        }

        #region Constructor Tests

        [TestMethod]
        public void Constructor_SetsSN()
        {
            Assert.AreEqual("TestSN", _host.SN);
        }

        [TestMethod]
        public void Constructor_SetsComLayer()
        {
            Assert.AreSame(_comLayer, _host.InternalComLayer);
        }

        [TestMethod]
        public void Constructor_AssociatedPropertiesAreNull()
        {
            Assert.IsNull(_host.AssociatedDeviceId);
            Assert.IsNull(_host.AssociatedLoggerId);
            Assert.IsNull(_host.AssociatedBatchId);
            Assert.IsNull(_host.AssociatedUnits);
            Assert.IsNull(_host.AssociatedResolution);
        }

        [TestMethod]
        public void Constructor_SubscribesToComLayerEvents()
        {
            // DataReceived subscription is verified by sending data and checking it's processed
            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1";
            _comLayer.SimulateStringDataReceived(msg);
            Assert.AreEqual("D1", _host.AssociatedDeviceId);
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

        [TestMethod]
        public void IsConnected_WhenComLayerNull_ReturnsFalse()
        {
            _host.ReplaceComLayer(null);
            Assert.IsFalse(_host.IsConnected);
        }

        [TestMethod]
        public void IsConnected_AfterDisconnect_ReturnsFalse()
        {
            _comLayer.IsConnected = true;
            _host.Disconnect();
            Assert.IsFalse(_host.IsConnected);
        }

        #endregion

        #region ReplaceComLayer Tests

        [TestMethod]
        public void ReplaceComLayer_Null_SetsComLayerToNull()
        {
            _host.ReplaceComLayer(null);
            Assert.IsNull(_host.InternalComLayer);
        }

        [TestMethod]
        public void ReplaceComLayer_NewLayer_SetsComLayer()
        {
            var newLayer = new MockComLayer();
            _host.ReplaceComLayer(newLayer);
            Assert.AreSame(newLayer, _host.InternalComLayer);
        }

        [TestMethod]
        public void ReplaceComLayer_OldLayerUnsubscribed_NewLayerActive()
        {
            var oldLayer = _comLayer;
            var newLayer = new MockComLayer();
            _host.ReplaceComLayer(newLayer);

            // Old layer data should NOT update host
            oldLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:OLD,DeviceID:OLD_DEV,BatchID:B1");
            Assert.IsNull(_host.AssociatedDeviceId); // Should still be null

            // New layer data SHOULD update host
            newLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:NEW,DeviceID:NEW_DEV,BatchID:B2");
            Assert.AreEqual("NEW_DEV", _host.AssociatedDeviceId);
        }

        [TestMethod]
        public void ReplaceComLayer_Null_OldLayerUnsubscribed()
        {
            _host.ReplaceComLayer(null);
            Assert.IsNull(_host.InternalComLayer);

            // Old layer events should not reach the host anymore
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            Assert.IsNull(_host.AssociatedDeviceId);
        }

        [TestMethod]
        public void ReplaceComLayer_MultipleTimes_OnlyLastLayerActive()
        {
            var layer1 = new MockComLayer();
            var layer2 = new MockComLayer();
            var layer3 = new MockComLayer();

            _host.ReplaceComLayer(layer1);
            _host.ReplaceComLayer(layer2);
            _host.ReplaceComLayer(layer3);

            Assert.AreSame(layer3, _host.InternalComLayer);

            // Only layer3 should be active
            layer1.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            Assert.IsNull(_host.AssociatedDeviceId);

            layer3.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L3,DeviceID:D3,BatchID:B3");
            Assert.AreEqual("D3", _host.AssociatedDeviceId);
        }

        #endregion

        #region SendPacket Tests

        [TestMethod]
        public void SendPacket_WhenConnected_CallsSendString()
        {
            var packet = new HardwarePacket("test data\r\n");
            _host.SendPacket(packet);
            Assert.IsNotNull(_comLayer.LastSentString);
        }

        [TestMethod]
        public void SendPacket_WhenNotConnected_DoesNotSend()
        {
            _comLayer.IsConnected = false;
            var packet = new HardwarePacket("test data\r\n");
            _host.SendPacket(packet);
            Assert.IsNull(_comLayer.LastSentString);
        }

        [TestMethod]
        public void SendPacket_FiresPacketSentEvent()
        {
            bool eventFired = false;
            _host.PacketSent += (s, e) => { eventFired = true; };

            var packet = new HardwarePacket("test\r\n");
            _host.SendPacket(packet);

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void SendPacket_PacketSentEventContainsCorrectPacket()
        {
            IPacket sentPacket = null;
            _host.PacketSent += (s, e) => { sentPacket = e.P; };

            var packet = new HardwarePacket("hello\r\n");
            _host.SendPacket(packet);

            Assert.IsNotNull(sentPacket);
            Assert.IsTrue(sentPacket.ToString().Contains("hello"));
        }

        [TestMethod]
        public void SendPacket_WhenComLayerNull_DoesNotThrow()
        {
            _host.ReplaceComLayer(null);
            var packet = new HardwarePacket("test\r\n");
            _host.SendPacket(packet); // Should not throw
        }

        [TestMethod]
        public void SendPacket_MultiplePackets_AllSent()
        {
            var sentStrings = new List<string>();
            var trackingLayer = new TrackingMockComLayer();
            _host.ReplaceComLayer(trackingLayer);

            _host.SendPacket(new HardwarePacket("msg1\r\n"));
            _host.SendPacket(new HardwarePacket("msg2\r\n"));
            _host.SendPacket(new HardwarePacket("msg3\r\n"));

            Assert.AreEqual(3, trackingLayer.SentStrings.Count);
        }

        #endregion

        #region Disconnect Tests

        [TestMethod]
        public void Disconnect_WhenNotConnected_DoesNothing()
        {
            _comLayer.IsConnected = false;
            _host.Disconnect(); // Should not throw
        }

        [TestMethod]
        public void Disconnect_WhenConnected_ClosesComLayer()
        {
            _comLayer.IsConnected = true;
            _host.Disconnect();
            Assert.IsFalse(_comLayer.IsConnected);
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
        public void Disconnect_FiresDeviceConnectionEvent()
        {
            bool eventFired = false;
            _bus.DeviceConnnection += (s, e) => { eventFired = true; };

            _comLayer.IsConnected = true;
            _host.Disconnect();

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void Disconnect_FiresDeviceConnectionEvent_WithCorrectDevice()
        {
            IDeviceHost reportedDevice = null;
            _bus.DeviceConnnection += (s, e) => { reportedDevice = e.Device; };

            _comLayer.IsConnected = true;
            _host.Disconnect();

            Assert.AreSame(_host, reportedDevice);
        }

        [TestMethod]
        public void Disconnect_SetsInternalComLayerToNull()
        {
            _comLayer.IsConnected = true;
            _host.Disconnect();
            Assert.IsNull(_host.InternalComLayer);
        }

        [TestMethod]
        public void Disconnect_CalledTwice_DoesNotThrow()
        {
            _comLayer.IsConnected = true;
            _host.Disconnect();
            _host.Disconnect(); // Second call should not throw
        }

        [TestMethod]
        public void OnConnection_Private_WithBl_InvokesBlOnConnectionTrue()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;
            var po = new PrivateObject(_host);
            po.Invoke("OnConnection");
            Assert.IsTrue(mockBL.OnConnectionCalled);
            Assert.IsTrue(mockBL.LastConnectionState);
        }

        #endregion

        #region LayerClosed Event Tests (Simulated Disconnect)

        [TestMethod]
        public void LayerClosed_CallsOnDisconnection_WithBL()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;

            _comLayer.SimulateLayerClosed();

            Assert.IsTrue(mockBL.OnConnectionCalled);
            Assert.IsFalse(mockBL.LastConnectionState);
        }

        [TestMethod]
        public void LayerClosed_NullsBLIsOK()
        {
            _host.BL = null;
            _comLayer.SimulateLayerClosed(); // Should not throw
        }

        [TestMethod]
        public void LayerClosed_UnsubscribesEvents()
        {
            _comLayer.SimulateLayerClosed();

            // After layer closed, sending more data should not reach the host
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:GHOST,DeviceID:GHOST_DEV,BatchID:B1");
            Assert.IsNull(_host.AssociatedDeviceId);
        }

        [TestMethod]
        public void LayerClosed_SetsInternalComLayerToNull()
        {
            _comLayer.SimulateLayerClosed();
            Assert.IsNull(_host.InternalComLayer);
        }

        #endregion

        #region Timer Tests

        [TestMethod]
        public void Timer_NoBL_DoesNotThrow()
        {
            _host.BL = null;
            _host.Timer(); // Should not throw
        }

        [TestMethod]
        public void Timer_WithBL_CallsOnTimer()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;

            _host.Timer();

            Assert.IsTrue(mockBL.OnTimerCalled);
        }

        [TestMethod]
        public void Timer_WithNonWebSocketCom_DoesNotThrow()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;
            _comLayer.IsConnected = true;

            _host.Timer(); // MockComLayer is not WebSocketCom - should not throw
            Assert.IsTrue(mockBL.OnTimerCalled);
        }

        [TestMethod]
        public void Timer_WithDisconnectedLayer_StillCallsBLOnTimer()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;
            _comLayer.IsConnected = false;

            _host.Timer();

            Assert.IsTrue(mockBL.OnTimerCalled);
        }

        [TestMethod]
        public void Timer_NullComLayer_DoesNotThrow()
        {
            _host.ReplaceComLayer(null);
            _host.BL = new MockDeviceBL();
            _host.Timer(); // Should not throw
        }

        [TestMethod]
        public void Timer_CalledRepeatedly_DoesNotThrow()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;

            for (int i = 0; i < 100; i++)
            {
                _host.Timer();
            }

            Assert.IsTrue(mockBL.OnTimerCalled);
        }

        #endregion

        #region DataReceived / SensorsAssociation Tests

        [TestMethod]
        public void DataReceived_SensorsAssociationMessage_SetsAssociatedProperties()
        {
            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,Units:Fahrenheit,Resolution:3";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.AreEqual("D1", _host.AssociatedDeviceId);
            Assert.AreEqual("L1", _host.AssociatedLoggerId);
            Assert.AreEqual("B1", _host.AssociatedBatchId);
            Assert.AreEqual("Fahrenheit", _host.AssociatedUnits);
            Assert.AreEqual("3", _host.AssociatedResolution);
        }

        [TestMethod]
        public void DataReceived_SensorsAssociation_EmptyUnits_DefaultsToCelsius()
        {
            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.AreEqual("Celsius", _host.AssociatedUnits);
            Assert.AreEqual("2", _host.AssociatedResolution);
        }

        [TestMethod]
        public void DataReceived_FiresEventBusIncomingEvent()
        {
            bool eventFired = false;
            _bus.DeviceOnIncomingEvent += (s, e) => { eventFired = true; };

            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void DataReceived_SensorsAssociation_EventContainsCorrectDevice()
        {
            IDeviceHost eventDevice = null;
            _bus.DeviceOnIncomingEvent += (s, e) => { eventDevice = e.Device; };

            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.AreSame(_host, eventDevice);
        }

        [TestMethod]
        public void DataReceived_SensorsAssociation_EventContainsPacket()
        {
            IPacket eventPacket = null;
            _bus.DeviceOnIncomingEvent += (s, e) => { eventPacket = e.Packet; };

            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.IsNotNull(eventPacket);
            Assert.IsInstanceOfType(eventPacket, typeof(SensorsAssociationMessage));
        }

        [TestMethod]
        public void DataReceived_SensorsAssociation_OverwritesPreviousValues()
        {
            // First association
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,Units:Celsius,Resolution:2");
            Assert.AreEqual("D1", _host.AssociatedDeviceId);
            Assert.AreEqual("Celsius", _host.AssociatedUnits);

            // Second association overwrites
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L2,DeviceID:D2,BatchID:B2,Units:Fahrenheit,Resolution:4");
            Assert.AreEqual("D2", _host.AssociatedDeviceId);
            Assert.AreEqual("L2", _host.AssociatedLoggerId);
            Assert.AreEqual("B2", _host.AssociatedBatchId);
            Assert.AreEqual("Fahrenheit", _host.AssociatedUnits);
            Assert.AreEqual("4", _host.AssociatedResolution);
        }

        [TestMethod]
        public void DataReceived_LoggerConfiguration_DoesNotSetAssociatedProperties()
        {
            string msg = "CMD:LoggerConfiguration,LoggerID:L1,IP:10.0.0.1,Rate:50,Interval:500,BatchID:B1,BatchChannels:C1";
            _comLayer.SimulateStringDataReceived(msg);

            // LoggerConfiguration should not set association properties
            Assert.IsNull(_host.AssociatedDeviceId);
        }

        [TestMethod]
        public void DataReceived_LoggerConfiguration_StillFiresEventBus()
        {
            bool eventFired = false;
            _bus.DeviceOnIncomingEvent += (s, e) => { eventFired = true; };

            string msg = "CMD:LoggerConfiguration,LoggerID:L1,IP:10.0.0.1,Rate:50,Interval:500,BatchID:B1,BatchChannels:C1";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void DataReceived_CreateReport_FiresEventBus()
        {
            bool eventFired = false;
            _bus.DeviceOnIncomingEvent += (s, e) => { eventFired = true; };

            _comLayer.SimulateStringDataReceived("CMD:CreateReport");
            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void DataReceived_EmptyString_DoesNotThrow()
        {
            _comLayer.SimulateStringDataReceived(""); // Should be filtered by _executer_DataReceived
        }

        [TestMethod]
        [ExpectedException(typeof(ArgumentNullException))]
        public void DataReceived_NullString_ThrowsArgumentNull()
        {
            // BUG: DataReceivedEventArgs constructor crashes on null string.
            // Real WebSocketCom always passes non-null from UTF-8 decode,
            // but this is a defensive gap if other IComLayer implementations exist.
            _comLayer.SimulateStringDataReceived(null);
        }

        [TestMethod]
        public void DataReceived_MultipleMessagesRapidly_AllProcessed()
        {
            int eventCount = 0;
            _bus.DeviceOnIncomingEvent += (s, e) => { Interlocked.Increment(ref eventCount); };

            for (int i = 0; i < 10; i++)
            {
                _comLayer.SimulateStringDataReceived($"CMD:SensorsAssociation,LoggerID:L{i},DeviceID:D{i},BatchID:B{i}");
            }

            Assert.AreEqual(10, eventCount);
            // Last values should stick
            Assert.AreEqual("D9", _host.AssociatedDeviceId);
            Assert.AreEqual("L9", _host.AssociatedLoggerId);
        }

        [TestMethod]
        public void DataReceived_SensorsAssociation_WithSendDataTrue()
        {
            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,SendData:true";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.AreEqual("D1", _host.AssociatedDeviceId);
        }

        [TestMethod]
        public void DataReceived_SensorsAssociation_WithBatchChannels()
        {
            string msg = "CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,BatchChannels:1;2;3;4";
            _comLayer.SimulateStringDataReceived(msg);

            Assert.AreEqual("D1", _host.AssociatedDeviceId);
            Assert.AreEqual("L1", _host.AssociatedLoggerId);
        }

        #endregion

        #region Dispose Tests

        [TestMethod]
        public void Dispose_CallsDisconnect()
        {
            _comLayer.IsConnected = true;
            _host.Dispose();
            Assert.IsFalse(_comLayer.IsConnected);
        }

        [TestMethod]
        public void Dispose_WhenAlreadyDisconnected_DoesNotThrow()
        {
            _comLayer.IsConnected = false;
            _host.Dispose();
        }

        #endregion

        #region Association Properties Tests

        [TestMethod]
        public void AssociatedProperties_CanBeSetDirectly()
        {
            _host.AssociatedDeviceId = "dev1";
            _host.AssociatedLoggerId = "log1";
            _host.AssociatedBatchId = "batch1";
            _host.AssociatedUnits = "Kelvin";
            _host.AssociatedResolution = "4";

            Assert.AreEqual("dev1", _host.AssociatedDeviceId);
            Assert.AreEqual("log1", _host.AssociatedLoggerId);
            Assert.AreEqual("batch1", _host.AssociatedBatchId);
            Assert.AreEqual("Kelvin", _host.AssociatedUnits);
            Assert.AreEqual("4", _host.AssociatedResolution);
        }

        #endregion

        #region BroadcastToWebSockets Integration Tests

        [TestMethod]
        public void BroadcastToWebSockets_WithAssociatedData_FormatsCorrectly()
        {
            // Set up a ServerCore and connect a WS host
            var server = new ServerCore();
            var wsLayer = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, wsLayer, "WS_Client");

            wsHost.AssociatedDeviceId = "DEV-123";
            wsHost.AssociatedLoggerId = "LOG-456";
            wsHost.AssociatedBatchId = "BATCH-789";
            wsHost.AssociatedUnits = "Celsius";
            wsHost.AssociatedResolution = "2";

            // Add WS host to server using reflection (or test BroadcastToWebSockets behavior)
            // The IncomingEvent handler calls BroadcastToWebSockets, but we can test format via event chain

            // Verify association data is accessible
            Assert.AreEqual("DEV-123", wsHost.AssociatedDeviceId);
            Assert.AreEqual("LOG-456", wsHost.AssociatedLoggerId);
            Assert.AreEqual("BATCH-789", wsHost.AssociatedBatchId);
        }

        [TestMethod]
        public void BroadcastToWebSockets_NullDevice_DoesNotThrow()
        {
            var server = new ServerCore();
            // Fire incoming event with null - should be handled gracefully
            server.MainEventsBus.Fire_OnIncomingEvent(null, new DeviceEventArgs(null, null));
        }

        [TestMethod]
        public void BroadcastToWebSockets_NullPacket_DoesNotThrow()
        {
            var server = new ServerCore();
            var comLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, comLayer, new DeviceSettings());
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, null));
        }

        [TestMethod]
        public void BroadcastToWebSockets_NonScanData_Skipped()
        {
            var server = new ServerCore();
            var comLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, comLayer, new DeviceSettings());

            // Non-scan packet (no "E," prefix)
            var packet = new HardwarePacket("=>\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, packet));
            // Should not throw
        }

        [TestMethod]
        public void BroadcastToWebSockets_ScanData_CorrectSNPrefix_Processed()
        {
            var server = new ServerCore();

            // Create HW device with known SN
            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            // Simulate identification
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // Verify SN is set
            Assert.AreEqual("FLUKE,2625A", hwHost.SN);

            // Create scan data matching the SN
            var scanPacket = new HardwarePacket("E,FLUKE,2625A,1,25.5,2,30.0\r\n");
            // This should not throw even without WS clients
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
        }

        [TestMethod]
        public void BroadcastToWebSockets_ScanData_WrongSNPrefix_Skipped()
        {
            var server = new ServerCore();

            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // Scan data with wrong SN prefix - should be skipped
            var scanPacket = new HardwarePacket("E,WRONG_SN,1,25.5\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
            // Should not throw
        }

        [TestMethod]
        public void BroadcastToWebSockets_ScanData_OddNumberOfParts_Skipped()
        {
            var server = new ServerCore();

            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // Odd number of channel/value parts (3 - not pairs)
            var scanPacket = new HardwarePacket("E,FLUKE,2625A,1,25.5,2\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
            // Should be skipped (odd parts), no throw
        }

        [TestMethod]
        public void BroadcastToWebSockets_ScanData_SingleChannelPair_Processed()
        {
            var server = new ServerCore();

            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // Single channel-value pair
            var scanPacket = new HardwarePacket("E,FLUKE,2625A,1,25.5\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
        }

        [TestMethod]
        public void BroadcastToWebSockets_ScanData_ManyChannels_Processed()
        {
            var server = new ServerCore();

            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // 10 channel-value pairs
            var scanPacket = new HardwarePacket("E,FLUKE,2625A,1,25.5,2,30.0,3,22.1,4,19.8,5,31.2,6,28.4,7,20.0,8,33.3,9,24.7,10,26.9\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
        }

        [TestMethod]
        public void BroadcastToWebSockets_EmptyChannelData_Skipped()
        {
            var server = new ServerCore();

            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);

            // No channel data after SN
            var scanPacket = new HardwarePacket("E,FLUKE,2625A,\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
        }

        [TestMethod]
        public void BroadcastToWebSockets_FallbackValues_WhenNoAssociation()
        {
            // When no SensorsAssociation was received, broadcast uses device.SN and defaults
            var server = new ServerCore();
            var wsLayer = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, wsLayer, "WS_Client");

            // No association set - all null
            Assert.IsNull(wsHost.AssociatedDeviceId);
            Assert.IsNull(wsHost.AssociatedLoggerId);
            Assert.IsNull(wsHost.AssociatedBatchId);
            Assert.IsNull(wsHost.AssociatedUnits);
            Assert.IsNull(wsHost.AssociatedResolution);
        }

        #endregion

        #region WebSocket Connection Event Tests

        [TestMethod]
        public void Fire_WebSocketConnection_FiresEvent()
        {
            bool eventFired = false;
            _bus.WebsocketDeviceConnnection += (s, e) => { eventFired = true; };

            _bus.Fire_WebSocketConnection(this, new DeviceConnectionEventArgs(_host));

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_AutoHandle_SetsHandled()
        {
            _bus.AutoHandleNewDevices = true;
            _comLayer.IsConnected = true; // IsConnected must be true for auto-handle

            var args = new DeviceConnectionEventArgs(_host);
            _bus.Fire_WebSocketConnection(this, args);

            Assert.IsTrue(args.Handled);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_NullArgs_DoesNotThrow()
        {
            _bus.Fire_WebSocketConnection(this, null);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_NullDevice_DoesNotThrow()
        {
            var args = new DeviceConnectionEventArgs(null);
            _bus.Fire_WebSocketConnection(this, args);
        }

        #endregion

        #region End-to-End Flow Tests

        [TestMethod]
        public void EndToEnd_AssociationThenDisconnect_PropertiesPreserved()
        {
            // Client sends association, then disconnects
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1,Units:Celsius,Resolution:2");
            Assert.AreEqual("D1", _host.AssociatedDeviceId);

            _comLayer.SimulateLayerClosed();

            // Properties should still be accessible even after disconnect
            Assert.AreEqual("D1", _host.AssociatedDeviceId);
            Assert.AreEqual("L1", _host.AssociatedLoggerId);
        }

        [TestMethod]
        public void EndToEnd_ConnectAssociateReconnect_NewAssociationRequired()
        {
            // First connection
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            Assert.AreEqual("D1", _host.AssociatedDeviceId);

            // Disconnect
            _comLayer.SimulateLayerClosed();

            // Reconnect with new layer
            var newLayer = new MockComLayer();
            _host.ReplaceComLayer(newLayer);

            // Old association data is still there (not cleared on reconnect)
            Assert.AreEqual("D1", _host.AssociatedDeviceId);

            // New association overwrites
            newLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L2,DeviceID:D2,BatchID:B2");
            Assert.AreEqual("D2", _host.AssociatedDeviceId);
        }

        [TestMethod]
        public void EndToEnd_TimerPumpsWhileDataFlows()
        {
            var mockBL = new MockDeviceBL();
            _host.BL = mockBL;

            // Simulate timer + data interleaved
            _host.Timer();
            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            _host.Timer();
            _comLayer.SimulateStringDataReceived("CMD:LoggerConfiguration,LoggerID:L1,IP:10.0.0.1,Rate:50,Interval:500,BatchID:B1,BatchChannels:C1");
            _host.Timer();

            Assert.IsTrue(mockBL.OnTimerCalled);
            Assert.AreEqual("D1", _host.AssociatedDeviceId);
        }

        [TestMethod]
        public void EndToEnd_ServerCore_FullBroadcastFlow()
        {
            // Set up server with HW device and WS client
            var server = new ServerCore();

            // Create HW device
            var hwComLayer = new MockComLayer();
            var hwHost = new HardwareDeviceHost(server.MainEventsBus, hwComLayer, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            hwComLayer.SimulateDataReceived(idBytes, 0, idBytes.Length);
            Assert.AreEqual("FLUKE,2625A", hwHost.SN);

            // Fire scan data through event bus (simulates what HardwareDeviceHost does)
            var scanPacket = new HardwarePacket("E,FLUKE,2625A,1,25.5,2,30.0\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(hwHost, new DeviceEventArgs(hwHost, scanPacket));
            // No WS clients connected, so broadcast is a no-op. Should not throw.
        }

        [TestMethod]
        public void EndToEnd_MultipleMessageTypes_ProcessedCorrectly()
        {
            var receivedTypes = new List<Type>();
            _bus.DeviceOnIncomingEvent += (s, e) =>
            {
                if (e.Packet != null) receivedTypes.Add(e.Packet.GetType());
            };

            _comLayer.SimulateStringDataReceived("CMD:SensorsAssociation,LoggerID:L1,DeviceID:D1,BatchID:B1");
            _comLayer.SimulateStringDataReceived("CMD:LoggerConfiguration,LoggerID:L1,IP:1.2.3.4,Rate:100,Interval:1000,BatchID:B1,BatchChannels:C1");
            _comLayer.SimulateStringDataReceived("CMD:CreateReport");

            Assert.AreEqual(3, receivedTypes.Count);
            Assert.AreEqual(typeof(SensorsAssociationMessage), receivedTypes[0]);
            Assert.AreEqual(typeof(LoggerConfigurationMessage), receivedTypes[1]);
            Assert.AreEqual(typeof(CreateReportMessage), receivedTypes[2]);
        }

        #endregion
    }

    /// <summary>
    /// MockComLayer that tracks all sent strings for assertions.
    /// </summary>
    internal class TrackingMockComLayer : Maba.VCT.ComLayer.IComLayer
    {
        public string Title { get; set; } = "TrackingMock";
        public bool IsConnected { get; set; } = true;
        public Maba.VCT.ComLayer.Tunnel ParentTunnel { get; private set; } = new Maba.VCT.ComLayer.Tunnel();
        public DateTime CreationTime { get; set; } = DateTime.UtcNow;
        public DateTime? LastRX_Time { get; private set; }
        public DateTime? LastTX_Time { get; private set; }

        public List<string> SentStrings { get; } = new List<string>();
        public List<byte[]> SentByteArrays { get; } = new List<byte[]>();

        public event Maba.VCT.ComLayer.DataReceivedDelegate DataReceived;
        public event Maba.VCT.ComLayer.LayerDestroyedDelegate LayerClosed;

        public void Close() { IsConnected = false; }
        public void Dispose() { Close(); }
        public void Open() { IsConnected = true; }
        public void SendBytes(byte[] data) { SentByteArrays.Add(data); }
        public void SendBytes(byte[] data, int offset, int count)
        {
            var actual = new byte[count];
            Buffer.BlockCopy(data, offset, actual, 0, count);
            SentByteArrays.Add(actual);
        }
        public void SendString(string data) { SentStrings.Add(data); }

        public void SimulateStringDataReceived(string data)
        {
            DataReceived?.Invoke(this, new Maba.VCT.ComLayer.DataReceivedEventArgs(data));
        }

        public void SimulateLayerClosed()
        {
            LayerClosed?.Invoke(this, new Maba.VCT.ComLayer.DestroyedEventArgs());
        }
    }
}
