using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Accessories;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.ComLayer;
using Maba.VCT.Core.Device;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-967 — Nofar, 2026-10-08. The Hydra 2625A was on the AUTO serial tunnel (COM6). The
    /// adapter's link died without anything noticing (.NET's <c>SerialPort.IsOpen</c> just turns
    /// false), rediscovery - which had never counted COM6 as held, because the tunnel says "AUTO" -
    /// opened COM6 a second time, and the re-init that followed had every reply swallowed by the
    /// poll request still waiting from the dead link. The device then sat with a dead link and no
    /// polling until the service was restarted two hours later.
    /// </summary>
    [TestClass]
    public class DeadLinkRecoveryTests
    {
        private static MyReaderWriterLockSlim<ConcurrentDictionary<string, HardwareDeviceHost>> DeviceHosts(ServerCore server)
        {
            var f = typeof(ServerCore).GetField("DeviceHost_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            return (MyReaderWriterLockSlim<ConcurrentDictionary<string, HardwareDeviceHost>>)f.GetValue(server);
        }

        private static MyReaderWriterLockSlim<List<DeviceHostPending>> PendingHosts(ServerCore server)
        {
            var f = typeof(ServerCore).GetField("DeviceHost_Pending_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            return (MyReaderWriterLockSlim<List<DeviceHostPending>>)f.GetValue(server);
        }

        private static void Identify(MockComLayer com)
        {
            var idn = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A,0,M5.5.1 A6.00 D1.0\r\n");
            com.SimulateDataReceived(idn, 0, idn.Length);
        }

        /// <summary>A logger that has been promoted into the server's device list, as after startup.</summary>
        private static HardwareDeviceHost PromotedLogger(ServerCore server, MockComLayer com)
        {
            var host = new HardwareDeviceHost(server.MainEventsBus, com, new DeviceSettings());
            Identify(com);
            host.InitSessions();
            DeviceHosts(server).MyWriteLock(d => d.TryAdd(host.SN, host));
            return host;
        }

        /// <summary>Queues a LOG_COUNT? and runs one tick, so it is sent and left waiting for its reply.</summary>
        private static void SendLogCount(HardwareDeviceHost host)
        {
            var request = new LogsRequest(LogsRequest.LogCommands.LogCount) { Packet = HydraProtocolHelper.Build_LogCountPacket() };
            host.GetLogs(request, r => { }).Wait();
            host.Timer();
        }

        // ------------------------------------------------------------------ the port is claimed

        [TestMethod]
        public void AnAutoTunnelsPort_IsClaimedByThePortItOpened()
        {
            // The tunnel says AUTO; the port it resolved to and opened is COM6. Claiming by the
            // tunnel's name claimed nothing, and COM6 was probed every 30 s all night.
            var server = new ServerCore();
            var auto = new Tunnel { Name = "SerialDevice_AUTO", SerialPortName = "AUTO" };
            var serial = new SerialCom("COM6", 9600, 100, auto);
            var host = new HardwareDeviceHost(server.MainEventsBus, serial, new DeviceSettings());
            DeviceHosts(server).MyWriteLock(d => d.TryAdd("FLUKE,2625A", host));

            var claimed = ServerCore.ClaimedSerialPorts(server.CurrentlyHeldTransports());

            CollectionAssert.Contains(claimed, "COM6");
        }

        [TestMethod]
        public void AnAutoTunnelsPort_IsClaimedWhileItIsStillPending()
        {
            var server = new ServerCore();
            var serial = new SerialCom("COM6", 9600, 100, new Tunnel { Name = "SerialDevice_AUTO", SerialPortName = "AUTO" });
            server.AddDevice_Pending_ComLayer(serial);

            CollectionAssert.Contains(ServerCore.ClaimedSerialPorts(server.CurrentlyHeldTransports()), "COM6");
        }

        [TestMethod]
        public void HeldTransport_ForANonSerialLink_IsItsTunnel()
        {
            var com = new MockComLayer();
            com.ParentTunnel.GpibPrimaryAddress = 7;

            Assert.AreSame(com.ParentTunnel, ServerCore.HeldTransport(com));
            Assert.IsNull(ServerCore.HeldTransport(null));
        }

        [TestMethod]
        public void ClaimedSerialPorts_SkipsAutoAndBlanks()
        {
            var claimed = ServerCore.ClaimedSerialPorts(new[]
            {
                new Tunnel { SerialPortName = "AUTO" },
                new Tunnel { SerialPortName = " COM3 " },
                new Tunnel { SerialPortName = "" },
                new Tunnel(),
                null,
            });

            CollectionAssert.AreEqual(new[] { "COM3" }, claimed);
            Assert.AreEqual(0, ServerCore.ClaimedSerialPorts(null).Count);
        }

        // ------------------------------------------------------------------ a dead link is let go

        [TestMethod]
        public void ADeadLink_IsClosedAndTheDeviceDisconnected()
        {
            var server = new ServerCore();
            var com = new MockComLayer();
            var host = PromotedLogger(server, com);
            var bl = new MockDeviceBL();
            host.BL = bl;

            com.IsConnected = false; // the adapter dropped: nothing closed, nothing raised

            Assert.AreEqual(1, server.ReleaseDeadLinks());

            Assert.AreEqual(1, com.CloseCount, "the dead handle has to be closed, not left to the finalizer");
            Assert.IsNull(host.InternalComLayer, "the host still holds the dead link, so its port stays claimed");
            Assert.IsTrue(host.DisconnectAlerted, "the operator was never told the logger had gone");
            Assert.IsFalse(bl.LastConnectionState, "the BL was not told the device dropped");
            Assert.AreEqual(0, ServerCore.ClaimedSerialPorts(server.CurrentlyHeldTransports()).Count);
        }

        [TestMethod]
        public void ADeadLink_ThatReportsClosing_IsDisconnectedOnce()
        {
            // SerialCom raises LayerClosed from Close; the device must not be disconnected twice.
            var server = new ServerCore();
            var com = new MockComLayer { RaiseLayerClosedOnClose = true };
            var host = PromotedLogger(server, com);
            var bl = new MockDeviceBL();
            host.BL = bl;
            com.IsConnected = false;

            Assert.IsTrue(host.ReleaseDeadLink());

            Assert.IsNull(host.InternalComLayer);
            Assert.AreEqual(1, bl.OnConnectionCallCount);
        }

        [TestMethod]
        public void ALiveLink_IsLeftAlone()
        {
            var server = new ServerCore();
            var com = new MockComLayer();
            var host = PromotedLogger(server, com);

            Assert.AreEqual(0, server.ReleaseDeadLinks());
            Assert.IsFalse(host.ReleaseDeadLink());
            Assert.AreEqual(0, com.CloseCount);
            Assert.AreSame(com, host.InternalComLayer);
        }

        [TestMethod]
        public void ADeadLink_ThatThrowsOnClose_IsStillLetGo()
        {
            var server = new ServerCore();
            var com = new MockComLayer { ThrowOnClose = true };
            var host = PromotedLogger(server, com);
            com.IsConnected = false;

            Assert.AreEqual(1, server.ReleaseDeadLinks());
            Assert.IsNull(host.InternalComLayer);
        }

        // ------------------------------------------------------------------ the device comes back

        [TestMethod]
        public void BackOnANewLink_AStaleRequestDoesNotHoldUpThePoll()
        {
            // 08:08:39: the poll's LOG_COUNT? went to the dead link and waited for a reply that
            // could never come. After the reconnect it took the replies of the whole re-init, and
            // a new poll could not go out until it timed out 60 s later.
            var server = new ServerCore();
            var oldCom = new MockComLayer();
            var host = PromotedLogger(server, oldCom);
            SendLogCount(host);
            oldCom.IsConnected = false;

            var newCom = new MockComLayer();
            var pending = new HardwareDeviceHost(server.MainEventsBus, newCom, new DeviceSettings());
            Identify(newCom);
            host.InitSessions(pending);

            SendLogCount(host);

            Assert.AreEqual("LOG_COUNT?", newCom.LastSentString?.Trim(),
                "the new link sent nothing: the session is still waiting for the dead link's reply");
        }

        [TestMethod]
        public void BackOnANewLink_TheDeadOneIsClosed()
        {
            var server = new ServerCore();
            var oldCom = new MockComLayer();
            var host = PromotedLogger(server, oldCom);
            oldCom.IsConnected = false;

            var newCom = new MockComLayer();
            var pending = new HardwareDeviceHost(server.MainEventsBus, newCom, new DeviceSettings());
            Identify(newCom);
            host.InitSessions(pending);

            Assert.AreSame(newCom, host.InternalComLayer);
            Assert.AreEqual(1, oldCom.CloseCount);
            Assert.AreEqual(0, newCom.CloseCount);
        }

        [TestMethod]
        public void BackOnANewLink_ALiveOldLinkIsNotClosed()
        {
            // Two live links with one SN: closing the old one would let rediscovery find it again
            // and swap back every 30 s.
            var server = new ServerCore();
            var oldCom = new MockComLayer();
            var host = PromotedLogger(server, oldCom);

            var newCom = new MockComLayer();
            var pending = new HardwareDeviceHost(server.MainEventsBus, newCom, new DeviceSettings());
            Identify(newCom);
            host.InitSessions(pending);

            Assert.AreEqual(0, oldCom.CloseCount);
        }

        [TestMethod]
        public void DeviceTick_DeadLinkAndTheDeviceBackOnANewOne_LeavesOneHostOnTheNewLink()
        {
            // The whole path through the device timer: the dead link is let go, the device found
            // again on the new link is handed to the same host, its BL is restarted, and a poll goes
            // out on the new link at once.
            var server = new ServerCore();
            server.MainEventsBus.AutoHandleNewDevices = true;

            var oldCom = new MockComLayer();
            var host = PromotedLogger(server, oldCom);
            var bl = new MockDeviceBL();
            host.BL = bl;
            SendLogCount(host);
            oldCom.IsConnected = false;

            var newCom = new MockComLayer();
            newCom.ParentTunnel.Name = "Serial COM6";
            server.AddDevice_Pending_ComLayer(newCom);
            Identify(newCom); // the pending host answers *IDN? with the same SN

            typeof(ServerCore).GetMethod("DeviceTick", BindingFlags.Instance | BindingFlags.NonPublic)
                              .Invoke(server, null);

            var hosts = new List<HardwareDeviceHost>();
            DeviceHosts(server).MyReadLock(d => hosts.AddRange(d.Values));
            int pendingCount = -1;
            PendingHosts(server).MyReadLock(list => pendingCount = list.Count);

            Assert.AreEqual(1, hosts.Count, "exactly one host drives the logger");
            Assert.AreSame(host, hosts[0]);
            Assert.AreEqual(0, pendingCount);
            Assert.AreSame(newCom, host.InternalComLayer);
            Assert.AreEqual(1, oldCom.CloseCount, "the dead link was dropped without being closed");
            Assert.IsTrue(bl.LastConnectionState, "the BL was not restarted on the new link");

            SendLogCount(host);
            Assert.AreEqual("LOG_COUNT?", newCom.LastSentString?.Trim());
        }

        // ------------------------------------------------------------------ the dead serial handle

        [TestMethod]
        public void SerialPortStillKeepsItsStreamWhereSerialComLooksForIt()
        {
            // Closing a dead port's handle goes through this private field. If a framework ever
            // renamed it, the close would quietly fall back to the finalizer.
            Assert.IsNotNull(SerialCom.InternalSerialStreamField);
            Assert.IsTrue(typeof(System.IO.Stream).IsAssignableFrom(SerialCom.InternalSerialStreamField.FieldType));
        }

        [TestMethod]
        public void CloseDeadStream_OnAPortNeverOpened_DoesNothing()
        {
            using (var port = new System.IO.Ports.SerialPort("COM250"))
            {
                SerialCom.CloseDeadStream(port);
                Assert.IsFalse(port.IsOpen);
            }
        }
    }
}
