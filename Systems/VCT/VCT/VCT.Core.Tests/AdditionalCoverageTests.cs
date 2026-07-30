using System;
using System.IO;
using System.Reflection;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using Maba.VCT.Core.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>Targets gaps for line coverage on small types and helpers.</summary>
    [TestClass]
    public class AdditionalCoverageTests
    {
        #region VCTTunnel0 / DeviceHostPending

        [TestMethod]
        public void VCTTunnel0_HoldsTunnelAndSettings()
        {
            var tunnel = new Maba.VCT.ComLayer.Tunnel { Name = "T1" };
            var ds = new DeviceSettings { SettingsName = "S1" };
            var v = new VCTTunnel0(tunnel, ds);
            Assert.AreSame(tunnel, v.Tunnel);
            Assert.AreSame(ds, v.DeviceSettings);
        }

        [TestMethod]
        public void DeviceHostPending_Properties_RoundTrip()
        {
            var p = new DeviceHostPending
            {
                Remove = true,
                TotalAwakeConnectPackets = 3,
                LastAwakeConnectPacket = DateTime.UtcNow,
                D = null
            };
            Assert.IsTrue(p.Remove);
            Assert.AreEqual(3, p.TotalAwakeConnectPackets);
            Assert.IsTrue(p.LastAwakeConnectPacket.HasValue);
        }

        #endregion

        #region Event args

        [TestMethod]
        public void DeviceConnectionEventArgs_Handled_Defaults()
        {
            var bus = new EventsBus();
            var com = new MockComLayer();
            var host = new HardwareDeviceHost(bus, com, new DeviceSettings());
            var args = new DeviceConnectionEventArgs(host);
            Assert.IsFalse(args.Handled);
        }

        [TestMethod]
        public void DeviceEventArgs_Ctor_StoresDeviceAndPacket()
        {
            var bus = new EventsBus();
            var com = new MockComLayer();
            var host = new HardwareDeviceHost(bus, com, new DeviceSettings());
            var pkt = new HardwarePacket("x\r\n");
            var e = new DeviceEventArgs(host, pkt);
            Assert.AreSame(host, e.Device);
            Assert.AreSame(pkt, e.Packet);
        }

        #endregion

        #region VCTSettings

        [TestMethod]
        public void VCTSettings_NormalizeWebSocketListenPrefix_NullUsesDefault()
        {
            var n = VCTSettings.NormalizeWebSocketListenPrefix(null);
            Assert.AreEqual(VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX, n);
        }

        [TestMethod]
        public void VCTSettings_NormalizeWebSocketListenPrefix_TrimsAndSlash()
        {
            var n = VCTSettings.NormalizeWebSocketListenPrefix("  http://0.0.0.0:9/ws  ");
            Assert.AreEqual("http://0.0.0.0:9/ws/", n);
        }

        #endregion

        #region ServerCore — EnableHardwareIdentification idempotent

        [TestMethod]
        public void EnableHardwareIdentification_WhenNotDeferred_IsNoOp()
        {
            var server = new ServerCore();
            server.DeferHardwareIdentificationPackets = false;
            server.EnableHardwareIdentification();
        }

        [TestMethod]
        public void EnableHardwareIdentification_WhenDeferred_OnlyFirstCallSetsUtc()
        {
            var server = new ServerCore();
            server.DeferHardwareIdentificationPackets = true;
            server.EnableHardwareIdentification();
            var f = typeof(ServerCore).GetField("_hardwareIdentificationStartedUtc", BindingFlags.Instance | BindingFlags.NonPublic);
            var first = (DateTime?)f.GetValue(server);
            Assert.IsTrue(first.HasValue);
            server.EnableHardwareIdentification();
            var second = (DateTime?)f.GetValue(server);
            Assert.AreEqual(first, second);
        }

        #endregion
    }
}
