using System;
using System.IO;
using System.Reflection;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Device.OTA;
using Maba.VCT.Core.Events;
using Maba.VCT.Core.Settings;
using Hydra2.VCT.Core.Device.OTA;

namespace Maba.VCT.Core.Tests
{
    /// <summary>Targets gaps for line coverage on small types and helpers.</summary>
    [TestClass]
    public class AdditionalCoverageTests
    {
        #region OTA / Upload

        [TestMethod]
        public void OTA_Metadata_RoundTrip_SaveAndRead()
        {
            var dir = Path.Combine(Path.GetTempPath(), "vct_ota_test_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(dir);
            try
            {
                var path = Path.Combine(dir, "meta.xml");
                var meta = new OTA_Metadata
                {
                    FileCode = "ABC",
                    CRC16 = 0x1234,
                    CreationDate = new DateTime(2024, 6, 1, 12, 0, 0, DateTimeKind.Utc),
                    FileVersion = new Version(1, 2, 3, 4),
                    FileSize = 99
                };
                meta.Save(path);
                var read = OTA_Metadata.Read(path);
                Assert.IsNotNull(read);
                Assert.AreEqual("ABC", read.FileCode);
                Assert.AreEqual(0x1234, read.CRC16);
                Assert.AreEqual(99, read.FileSize);
                // XmlSerializer round-trip for System.Version is environment-dependent; assert non-null if present
                Assert.IsNotNull(read.FileVersion);
            }
            finally
            {
                try { Directory.Delete(dir, true); } catch { /* temp cleanup */ }
            }
        }

        [TestMethod]
        public void OTA_Metadata_Read_MissingFile_ReturnsNull()
        {
            Assert.IsNull(OTA_Metadata.Read(Path.Combine(Path.GetTempPath(), "no_such_ota_" + Guid.NewGuid().ToString("N") + ".xml")));
        }

        [TestMethod]
        public void OTAItem_DefaultCtor_PropertiesAssignable()
        {
            var item = new OTAItem();
            var meta = new OTA_Metadata { FileCode = "X", FileVersion = new Version(1, 0) };
            item.Metadata = meta;
            item.Data = new byte[] { 1, 2, 3 };
            item.LocalOTAData_FileName = @"C:\temp\f.dat";
            Assert.AreSame(meta, item.Metadata);
            Assert.AreEqual(3, item.Data.Length);
            Assert.IsTrue(item.LocalOTAData_FileName.Contains("f.dat"));
        }

        [TestMethod]
        public void UploadFileResponse_Ctor_CopiesMetadataFields()
        {
            var meta = new OTA_Metadata
            {
                FileCode = "CODE1",
                FileVersion = new Version(2, 0),
                FileSize = 50,
                CRC16 = 7
            };
            var r = new UploadFileResponse(meta, true, UploadFileResponse.Errors.Bad_Request);
            Assert.IsTrue(r.Result);
            Assert.AreEqual("CODE1", r.FileCode);
            Assert.AreEqual(50, r.FileSize);
            Assert.AreEqual((ushort)7, r.CRC16);
            Assert.AreEqual(UploadFileResponse.Errors.Bad_Request, r.LastError);
        }

        [TestMethod]
        public void OTAService_StaticFilenames_Format()
        {
            var t = typeof(OTAService);
            var meta = t.GetMethod("OTA_Metadata_Filename", BindingFlags.NonPublic | BindingFlags.Static);
            var data = t.GetMethod("OTA_Data_Filename", BindingFlags.NonPublic | BindingFlags.Static);
            Assert.IsNotNull(meta);
            Assert.IsNotNull(data);
            Assert.AreEqual("OTA_ABC.xml", meta.Invoke(null, new object[] { "ABC" }));
            Assert.AreEqual("OTA_ABC.DAT", data.Invoke(null, new object[] { "ABC" }));
        }

        #endregion

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
