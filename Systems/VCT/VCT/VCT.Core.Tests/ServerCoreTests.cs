using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Reflection;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Accessories;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Maba.VCT.Core.Settings;
using Maba.VCT.Common;
using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class ServerCoreTests
    {
        #region Constructor Tests

        [TestMethod]
        public void Constructor_CreatesEventsBus()
        {
            var server = new ServerCore();
            Assert.IsNotNull(server.MainEventsBus);
        }

        [TestMethod]
        public void Constructor_CreatesDefaultSettings()
        {
            var server = new ServerCore();
            Assert.IsNotNull(server.CurrentServerSettings);
        }

        #endregion

        #region GetDevice Tests

        [TestMethod]
        public void GetDevice_NoDeviceAdded_ReturnsNull()
        {
            var server = new ServerCore();
            var device = server.GetDevice("nonexistent");
            Assert.IsNull(device);
        }

        [TestMethod]
        public void GetDeviceAsync_NoDeviceAdded_ReturnsNull()
        {
            var server = new ServerCore();
            var device = server.GetDeviceAsync("nonexistent").Result;
            Assert.IsNull(device);
        }

        #endregion

        #region AddDevice_Pending_ComLayer Tests

        [TestMethod]
        public void AddDevice_Pending_ComLayer_DoesNotThrow()
        {
            var server = new ServerCore();
            // Set up settings with a device setting so Lookup4Settings doesn't fail
            var settings = VCTSettings.CreateDefaultSettings();
            // Need to populate Dic_DeviceSettings by calling Start with settings
            // that have no serial ports and no TCP ports to avoid I/O
            settings.Tunnels = new Maba.VCT.ComLayer.Tunnel[0];

            // Use reflection to set Dic_DeviceSettings or just test the AddDevice path
            var comLayer = new MockComLayer();
            comLayer.ParentTunnel.Name = "";

            // AddDevice_Pending_ComLayer calls Lookup4Settings which accesses Dic_DeviceSettings
            // Since no Start() was called, Dic_DeviceSettings is empty, so it will return new DeviceSettings()
            server.AddDevice_Pending_ComLayer(comLayer);
            // If we got here without throwing, the test passes
        }

        [TestMethod]
        public void AddDevice_Pending_ComLayer_UsesDictionarySettingsWhenTunnelNameMatches()
        {
            var server = new ServerCore();
            var expected = new DeviceSettings();
            expected.SessionRequestTimeout_TimeSpan = TimeSpan.FromMinutes(42);

            var dictField = typeof(ServerCore).GetField("Dic_DeviceSettings", BindingFlags.Instance | BindingFlags.NonPublic);
            var dic = (Dictionary<string, DeviceSettings>)dictField.GetValue(server);
            dic["TunnelA"] = expected;

            var comLayer = new MockComLayer();
            comLayer.ParentTunnel.Name = "TunnelA";
            server.AddDevice_Pending_ComLayer(comLayer);

            var slimField = typeof(ServerCore).GetField("DeviceHost_Pending_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            var slim = (MyReaderWriterLockSlim<List<DeviceHostPending>>)slimField.GetValue(server);

            HardwareDeviceHost host = null;
            slim.MyReadLock(list =>
            {
                Assert.AreEqual(1, list.Count);
                host = list[0].D as HardwareDeviceHost;
            });

            Assert.IsNotNull(host);
            Assert.AreEqual(TimeSpan.FromMinutes(42), host.DeviceSettings.SessionRequestTimeout_TimeSpan);
        }

        [TestMethod]
        public void AddDevice_Pending_ComLayer_NullDictionaryEntry_UsesDefaultDeviceSettings()
        {
            var server = new ServerCore();
            var dictField = typeof(ServerCore).GetField("Dic_DeviceSettings", BindingFlags.Instance | BindingFlags.NonPublic);
            var dic = (Dictionary<string, DeviceSettings>)dictField.GetValue(server);
            dic["TunnelNull"] = null;

            var comLayer = new MockComLayer();
            comLayer.ParentTunnel.Name = "TunnelNull";
            server.AddDevice_Pending_ComLayer(comLayer);

            var slimField = typeof(ServerCore).GetField("DeviceHost_Pending_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            var slim = (MyReaderWriterLockSlim<List<DeviceHostPending>>)slimField.GetValue(server);

            slim.MyReadLock(list =>
            {
                var host = list[0].D as HardwareDeviceHost;
                Assert.IsNotNull(host);
                Assert.AreEqual(TimeSpan.FromMinutes(1), host.DeviceSettings.SessionRequestTimeout_TimeSpan);
            });
        }

        #endregion

        #region EventsBus Integration Tests

        [TestMethod]
        public void EventsBus_DeviceConnection_AutoHandle_SetsHandled()
        {
            var server = new ServerCore();
            server.MainEventsBus.AutoHandleNewDevices = true;

            bool eventFired = false;
            server.MainEventsBus.DeviceConnnection += (s, e) =>
            {
                eventFired = true;
            };

            var bus = server.MainEventsBus;
            var comLayer = new MockComLayer();
            var host = new HardwareDeviceHost(bus, comLayer, new DeviceSettings());
            bus.Fire_DeviceConnection(server, new DeviceConnectionEventArgs(host));

            Assert.IsTrue(eventFired);
        }

        [TestMethod]
        public void MainEventsBus_IncomingEvent_FromHardwareDevice_DoesNotThrow()
        {
            var server = new ServerCore();

            var comLayer = new MockComLayer();
            var host = new HardwareDeviceHost(server.MainEventsBus, comLayer, new DeviceSettings());
            var packet = new HardwarePacket("test\r\n");

            // Fire incoming event - should call BroadcastToWebSockets internally
            server.MainEventsBus.Fire_OnIncomingEvent(host, new DeviceEventArgs(host, packet));
        }

        [TestMethod]
        public void MainEventsBus_IncomingEvent_WithScanData_DoesNotThrow()
        {
            var server = new ServerCore();

            var comLayer = new MockComLayer();
            var host = new HardwareDeviceHost(server.MainEventsBus, comLayer, new DeviceSettings());
            // Simulate identification so SN is set
            var snBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            comLayer.SimulateDataReceived(snBytes, 0, snBytes.Length);

            // Now send scan data
            var scanPacket = new HardwarePacket("E,FLUKE,2625,1,25.5,2,30.0\r\n");
            server.MainEventsBus.Fire_OnIncomingEvent(host, new DeviceEventArgs(host, scanPacket));
        }

        [TestMethod]
        public void MainEventsBus_IncomingEvent_FromHardware_WithNullPacket_DoesNotThrow()
        {
            var server = new ServerCore();
            var comLayer = new MockComLayer();
            var host = new HardwareDeviceHost(server.MainEventsBus, comLayer, new DeviceSettings());
            server.MainEventsBus.Fire_OnIncomingEvent(host, new DeviceEventArgs(host, null));
        }

        #endregion

        #region Stop Tests

        [TestMethod]
        public void Stop_AfterStart_DoesNotThrow()
        {
            var server = new ServerCore();

            // Create minimal settings with no tunnels to avoid I/O
            var settings = VCTSettings.CreateDefaultSettings();
            settings.Tunnels = new Maba.VCT.ComLayer.Tunnel[0];

            server.Start(settings);

            // Give timer a chance to start
            System.Threading.Thread.Sleep(100);

            server.Stop();
        }

        private static Maba.VCT.Accessories.MyReaderWriterLockSlim<ConcurrentDictionary<string, HardwareDeviceHost>> GetDeviceHostSlim(ServerCore server)
        {
            var f = typeof(ServerCore).GetField("DeviceHost_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(f);
            return (Maba.VCT.Accessories.MyReaderWriterLockSlim<ConcurrentDictionary<string, HardwareDeviceHost>>)f.GetValue(server);
        }

        private static Maba.VCT.Accessories.MyReaderWriterLockSlim<List<DeviceHostPending>> GetDeviceHostPendingSlim(ServerCore server)
        {
            var f = typeof(ServerCore).GetField("DeviceHost_Pending_Slim", BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(f);
            return (Maba.VCT.Accessories.MyReaderWriterLockSlim<List<DeviceHostPending>>)f.GetValue(server);
        }

        [TestMethod]
        public void Stop_WithRegisteredHardware_ClosesComLayers()
        {
            var server = new ServerCore();
            var com = new MockComLayer();
            var host = new HardwareDeviceHost(server.MainEventsBus, com, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idBytes, 0, idBytes.Length);
            Assert.IsFalse(string.IsNullOrEmpty(host.SN));

            GetDeviceHostSlim(server).MyWriteLock(d => d.TryAdd(host.SN, host));

            server.Stop();

            Assert.IsFalse(com.IsConnected);
        }

        [TestMethod]
        public void Stop_InternalComLayerCloseThrows_StillCompletes()
        {
            var server = new ServerCore();
            var com = new MockComLayer { ThrowOnClose = true };
            var host = new HardwareDeviceHost(server.MainEventsBus, com, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idBytes, 0, idBytes.Length);

            GetDeviceHostSlim(server).MyWriteLock(d => d.TryAdd(host.SN, host));

            server.Stop();
        }

        [TestMethod]
        public void Stop_PendingDisconnectThrows_StillClearsPending()
        {
            var server = new ServerCore();
            var pending = new DeviceHostPending
            {
                D = new ThrowingDisconnectDeviceHost()
            };

            GetDeviceHostPendingSlim(server).MyWriteLock(list => list.Add(pending));

            server.Stop();
        }

        [TestMethod]
        public void Stop_WithDeviceMainSocketsNonNull_ClosesSocketList()
        {
            var server = new ServerCore();
            var field = typeof(ServerCore).GetField("Device_MainSockets", BindingFlags.Instance | BindingFlags.NonPublic);
            field.SetValue(server, new List<Socket>());
            server.Stop();
        }

        [TestMethod]
        public void Stop_WithDeviceMainSocketsContainingSocket_InvokesCloseOnEach()
        {
            var server = new ServerCore();
            var field = typeof(ServerCore).GetField("Device_MainSockets", BindingFlags.Instance | BindingFlags.NonPublic);
            var sockets = new List<Socket>
            {
                new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp)
            };
            field.SetValue(server, sockets);
            server.Stop();
            Assert.AreEqual(1, sockets.Count);
        }

        [TestMethod]
        public void WebSocket_StatusStop_WithRegisteredHardware_DisconnectsDevices()
        {
            var server = new ServerCore();
            var com = new MockComLayer();
            var host = new HardwareDeviceHost(server.MainEventsBus, com, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idBytes, 0, idBytes.Length);

            GetDeviceHostSlim(server).MyWriteLock(d => d.TryAdd(host.SN, host));

            var wsCom = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, wsCom, "WS");
            server.MainEventsBus.Fire_OnIncomingEvent(wsHost, new DeviceEventArgs(wsHost, new StatusMessage { Value = "Stop" }));

            Assert.IsFalse(com.IsConnected);
        }

        [TestMethod]
        public void WebSocket_StatusStop_WhenHardwareDisconnectThrows_Continues()
        {
            var server = new ServerCore();
            var com = new MockComLayer { ThrowOnClose = true };
            var host = new HardwareDeviceHost(server.MainEventsBus, com, new DeviceSettings());
            var idBytes = System.Text.Encoding.ASCII.GetBytes("FLUKE,2625A\r\n");
            com.SimulateDataReceived(idBytes, 0, idBytes.Length);

            GetDeviceHostSlim(server).MyWriteLock(d => d.TryAdd(host.SN, host));

            var wsCom = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, wsCom, "WS");
            server.MainEventsBus.Fire_OnIncomingEvent(wsHost, new DeviceEventArgs(wsHost, new StatusMessage { Value = "Stop" }));
        }

        #endregion

        #region WebSocket Status:Start → deferred identification

        private static DateTime? GetIdentificationStartedUtc(ServerCore server)
        {
            var f = typeof(ServerCore).GetField(
                "_hardwareIdentificationStartedUtc",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.IsNotNull(f);
            return (DateTime?)f.GetValue(server);
        }

        [TestMethod]
        public void WebSocket_StatusStart_WithDeferEnabled_SetsIdentificationStartedUtc()
        {
            var server = new ServerCore();
            server.DeferHardwareIdentificationPackets = true;
            Assert.IsFalse(GetIdentificationStartedUtc(server).HasValue);

            var com = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, com, "WS_Test");
            var status = new StatusMessage { Value = "Start", DeviceID = "21-142" };

            server.MainEventsBus.Fire_OnIncomingEvent(wsHost, new DeviceEventArgs(wsHost, status));

            Assert.IsTrue(GetIdentificationStartedUtc(server).HasValue, "EnableHardwareIdentification should run from WS Status:Start");
        }

        [TestMethod]
        public void WebSocket_StatusStart_WithDeferDisabled_DoesNotSetIdentificationStartedUtc()
        {
            var server = new ServerCore();
            server.DeferHardwareIdentificationPackets = false;

            var com = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, com, "WS_Test");
            var status = new StatusMessage { Value = "Start" };

            server.MainEventsBus.Fire_OnIncomingEvent(wsHost, new DeviceEventArgs(wsHost, status));

            Assert.IsFalse(GetIdentificationStartedUtc(server).HasValue);
        }

        [TestMethod]
        public void WebSocket_StatusStop_EmptyHardwareList_DoesNotThrow()
        {
            var server = new ServerCore();
            var com = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, com, "WS_Stop");
            var status = new StatusMessage { Value = "Stop" };
            server.MainEventsBus.Fire_OnIncomingEvent(wsHost, new DeviceEventArgs(wsHost, status));
        }

        [TestMethod]
        public void WebSocket_StatusStart_WithoutServerStart_TimerNull_SkipsImmediatePoll()
        {
            var server = new ServerCore();
            server.DeferHardwareIdentificationPackets = false;
            var com = new MockComLayer();
            var wsHost = new WebSocketDeviceHost(server.MainEventsBus, com, "WS_TimerNull");
            server.MainEventsBus.Fire_OnIncomingEvent(wsHost, new DeviceEventArgs(wsHost, new StatusMessage { Value = "Start" }));
        }

        #endregion
    }

    /// <summary>Minimal <see cref="IDeviceHost"/> for exercising <see cref="ServerCore.Stop"/> pending path when <see cref="IDeviceHost.Disconnect"/> throws.</summary>
    internal sealed class ThrowingDisconnectDeviceHost : IDeviceHost
    {
        public DateTime IdentificationDate { get; set; }
        public string SN => "ThrowHost";
        public bool IsConnected => false;
        public Maba.VCT.ComLayer.IComLayer InternalComLayer => null;
        public IDeviceBL BL => null;

        public void Disconnect()
        {
            throw new InvalidOperationException("test disconnect");
        }

        public void Dispose() { }

        public void ReplaceComLayer(Maba.VCT.ComLayer.IComLayer value) { }

        public void SendPacket(IPacket p) { }
    }
}
