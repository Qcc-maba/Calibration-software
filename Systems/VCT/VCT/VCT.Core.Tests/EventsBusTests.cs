using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Core.Events;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class EventsBusTests
    {
        private EventsBus _bus;

        [TestInitialize]
        public void Setup()
        {
            _bus = new EventsBus();
        }

        #region AutoHandleNewDevices Tests

        [TestMethod]
        public void AutoHandleNewDevices_DefaultIsFalse()
        {
            Assert.IsFalse(_bus.AutoHandleNewDevices);
        }

        [TestMethod]
        public void AutoHandleNewDevices_CanBeSetToTrue()
        {
            _bus.AutoHandleNewDevices = true;

            Assert.IsTrue(_bus.AutoHandleNewDevices);
        }

        #endregion

        #region Fire_OnIncomingEvent Tests

        [TestMethod]
        public void Fire_OnIncomingEvent_NoSubscribers_DoesNotThrow()
        {
            var device = new MockDeviceHost();
            var args = new DeviceEventArgs(device, null);

            _bus.Fire_OnIncomingEvent(this, args);
            // No exception expected
        }

        [TestMethod]
        public void Fire_OnIncomingEvent_WithSubscriber_InvokesHandler()
        {
            bool fired = false;
            DeviceEventArgs receivedArgs = null;

            _bus.DeviceOnIncomingEvent += (o, e) =>
            {
                fired = true;
                receivedArgs = e;
            };

            var device = new MockDeviceHost();
            var args = new DeviceEventArgs(device, null);
            _bus.Fire_OnIncomingEvent(this, args);

            Assert.IsTrue(fired);
            Assert.AreSame(args, receivedArgs);
        }

        #endregion

        #region Fire_DeviceConnection Tests

        [TestMethod]
        public void Fire_DeviceConnection_NoSubscribers_DoesNotThrow()
        {
            var device = new MockDeviceHost { MockIsConnected = false };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_DeviceConnection(this, args);
        }

        [TestMethod]
        public void Fire_DeviceConnection_WithSubscriber_InvokesHandler()
        {
            bool fired = false;
            _bus.DeviceConnnection += (o, e) => { fired = true; };

            var device = new MockDeviceHost { MockIsConnected = false };
            var args = new DeviceConnectionEventArgs(device);
            _bus.Fire_DeviceConnection(this, args);

            Assert.IsTrue(fired);
        }

        [TestMethod]
        public void Fire_DeviceConnection_ConnectedDeviceWithAutoHandle_SetsHandledTrue()
        {
            _bus.AutoHandleNewDevices = true;
            var device = new MockDeviceHost { MockIsConnected = true };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_DeviceConnection(this, args);

            Assert.IsTrue(args.Handled);
        }

        [TestMethod]
        public void Fire_DeviceConnection_DisconnectedDeviceWithAutoHandle_HandledRemainsFalse()
        {
            _bus.AutoHandleNewDevices = true;
            var device = new MockDeviceHost { MockIsConnected = false };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_DeviceConnection(this, args);

            Assert.IsFalse(args.Handled);
        }

        [TestMethod]
        public void Fire_DeviceConnection_ConnectedDeviceWithoutAutoHandle_HandledRemainsFalse()
        {
            _bus.AutoHandleNewDevices = false;
            var device = new MockDeviceHost { MockIsConnected = true };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_DeviceConnection(this, args);

            Assert.IsFalse(args.Handled);
        }

        #endregion

        #region Fire_WebSocketConnection Tests

        [TestMethod]
        public void Fire_WebSocketConnection_NullArgs_DoesNotThrow()
        {
            _bus.Fire_WebSocketConnection(this, null);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_NullDevice_DoesNotThrow()
        {
            var args = new DeviceConnectionEventArgs(null);
            // The method checks e.Device == null, which is the case since DeviceConnectionEventArgs
            // constructor sets Device to null
            _bus.Fire_WebSocketConnection(this, args);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_WithSubscriber_InvokesHandler()
        {
            bool fired = false;
            _bus.WebsocketDeviceConnnection += (o, e) => { fired = true; };

            var device = new MockDeviceHost { MockIsConnected = false };
            var args = new DeviceConnectionEventArgs(device);
            _bus.Fire_WebSocketConnection(this, args);

            Assert.IsTrue(fired);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_ConnectedWithAutoHandle_SetsHandledTrue()
        {
            _bus.AutoHandleNewDevices = true;
            var device = new MockDeviceHost { MockIsConnected = true };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_WebSocketConnection(this, args);

            Assert.IsTrue(args.Handled);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_DisconnectedWithAutoHandle_HandledRemainsFalse()
        {
            _bus.AutoHandleNewDevices = true;
            var device = new MockDeviceHost { MockIsConnected = false };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_WebSocketConnection(this, args);

            Assert.IsFalse(args.Handled);
        }

        [TestMethod]
        public void Fire_WebSocketConnection_NoSubscribers_DoesNotThrow()
        {
            var device = new MockDeviceHost { MockIsConnected = true };
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_WebSocketConnection(this, args);
        }

        #endregion

        #region Fire_UnIdentifiedConnection Tests

        [TestMethod]
        public void Fire_UnIdentifiedConnection_NoSubscribers_DoesNotThrow()
        {
            var device = new MockDeviceHost();
            var args = new DeviceConnectionEventArgs(device);

            _bus.Fire_UnIdentifiedConnection(this, args);
        }

        [TestMethod]
        public void Fire_UnIdentifiedConnection_WithSubscriber_InvokesHandler()
        {
            bool fired = false;
            DeviceConnectionEventArgs receivedArgs = null;

            _bus.DeviceUnIdentifyConnnection += (o, e) =>
            {
                fired = true;
                receivedArgs = e;
            };

            var device = new MockDeviceHost();
            var args = new DeviceConnectionEventArgs(device);
            _bus.Fire_UnIdentifiedConnection(this, args);

            Assert.IsTrue(fired);
            Assert.AreSame(args, receivedArgs);
        }

        #endregion

        #region DeviceConnectionEventArgs Tests

        [TestMethod]
        public void DeviceConnectionEventArgs_DefaultHandledIsFalse()
        {
            var device = new MockDeviceHost();
            var args = new DeviceConnectionEventArgs(device);

            Assert.IsFalse(args.Handled);
        }

        [TestMethod]
        public void DeviceConnectionEventArgs_DeviceIsSet()
        {
            var device = new MockDeviceHost();
            var args = new DeviceConnectionEventArgs(device);

            Assert.AreSame(device, args.Device);
        }

        #endregion

        #region DeviceEventArgs Tests

        [TestMethod]
        public void DeviceEventArgs_ConstructorSetsProperties()
        {
            var device = new MockDeviceHost();
            var packet = new Maba.VCT.Common.HardwarePacket("test");
            var args = new DeviceEventArgs(device, packet);

            Assert.AreSame(device, args.Device);
            Assert.AreSame(packet, args.Packet);
        }

        #endregion
    }

    /// <summary>
    /// Minimal mock for IDeviceHost used in EventsBus tests.
    /// </summary>
    internal class MockDeviceHost : Maba.VCT.Core.Device.IDeviceHost
    {
        public bool MockIsConnected { get; set; } = false;

        public DateTime IdentificationDate { get; set; }
        public string SN { get; private set; }
        public bool IsConnected => MockIsConnected;
        public Maba.VCT.ComLayer.IComLayer InternalComLayer { get; private set; }
        public Maba.VCT.Core.Device.IDeviceBL BL { get; set; }

        public void Disconnect() { }
        public void Dispose() { }
        public void ReplaceComLayer(Maba.VCT.ComLayer.IComLayer comLayer) { }
        public void SendPacket(Maba.VCT.Common.IPacket p) { }
    }
}
