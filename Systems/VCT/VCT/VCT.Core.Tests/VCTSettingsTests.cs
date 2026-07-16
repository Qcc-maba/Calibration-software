using System;
using System.IO;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Core.Settings;

namespace Maba.VCT.Core.Tests
{
    /// <summary>Uses <see cref="VCTSettings.VCT_SETTINGS_FULL_PATH_ENV"/>; must not run in parallel with other tests that touch the same env var.</summary>
    [TestClass]
    [DoNotParallelize]
    public class VCTSettingsTests
    {
        [TestInitialize]
        public void ClearVctSettingsPathEnv()
        {
            Environment.SetEnvironmentVariable(VCTSettings.VCT_SETTINGS_FULL_PATH_ENV, null);
        }

        #region Constructor Tests

        [TestMethod]
        public void Constructor_DefaultMaxAwakePacketTimes_Is5()
        {
            var settings = new VCTSettings();
            Assert.AreEqual(5, settings.PendingDevice_MaxAwakePacketTimes);
        }

        #endregion

        #region CreateDefaultSettings Tests

        [TestMethod]
        public void CreateDefaultSettings_ReturnsNonNull()
        {
            var settings = VCTSettings.CreateDefaultSettings();
            Assert.IsNotNull(settings);
        }

        [TestMethod]
        public void CreateDefaultSettings_HasTunnels()
        {
            var settings = VCTSettings.CreateDefaultSettings();
            Assert.IsNotNull(settings.Tunnels);
            Assert.AreEqual(2, settings.Tunnels.Length);
        }

        [TestMethod]
        public void CreateDefaultSettings_WebSocketListenPrefix_IsDefault()
        {
            var settings = VCTSettings.CreateDefaultSettings();
            Assert.AreEqual(VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX, settings.WebSocketListenPrefix);
        }

        [TestMethod]
        public void NormalizeWebSocketListenPrefix_AddsTrailingSlash()
        {
            Assert.AreEqual("http://127.0.0.1:9000/ws/", VCTSettings.NormalizeWebSocketListenPrefix("http://127.0.0.1:9000/ws"));
        }

        [TestMethod]
        public void CreateDefaultSettings_TunnelHasTwoPorts()
        {
            var settings = VCTSettings.CreateDefaultSettings();
            Assert.IsNotNull(settings.Tunnels[0].Ports);
            Assert.AreEqual(2, settings.Tunnels[0].Ports.Length);
        }

        [TestMethod]
        public void CreateDefaultSettings_DeviceSettingsNotEmpty()
        {
            var settings = VCTSettings.CreateDefaultSettings();
            Assert.IsNotNull(settings.DeviceSettings);
            Assert.IsTrue(settings.DeviceSettings.Length > 0);
        }

        #endregion

        #region Computed Property Tests

        [TestMethod]
        public void ServerTimerInterval_Is2000()
        {
            var settings = new VCTSettings();
            Assert.AreEqual(2000, settings.ServerTimerInterval);
        }

        [TestMethod]
        public void PendingDevice_MaximumSilence_IsOneMinute()
        {
            var settings = new VCTSettings();
            Assert.AreEqual(TimeSpan.FromMinutes(1), settings.PendingDevice_MaximumSilence_TimeSpan);
        }

        [TestMethod]
        public void PendingDevice_AwakePacketInterval_Is10Seconds()
        {
            var settings = new VCTSettings();
            Assert.AreEqual(TimeSpan.FromSeconds(10), settings.PendingDevice_AwakePacketInterval_TimeSpan);
        }

        [TestMethod]
        public void GeneralDBName_IsKyulanSyncDB()
        {
            var settings = new VCTSettings();
            Assert.AreEqual("KyulanSyncDB", settings.GeneralDBName);
        }

        [TestMethod]
        public void PriorityDBName_IsPriority()
        {
            var settings = new VCTSettings();
            Assert.AreEqual("Priority", settings.PriorityDBName);
        }

        [TestMethod]
        public void PendingDevice_FirstAwakePacket_IsOneSecond()
        {
            var settings = new VCTSettings();
            Assert.AreEqual(TimeSpan.FromSeconds(1), settings.PendingDevice_FirstAwakePacket_TimeSpan);
        }

        #endregion

        #region Static paths

        [TestMethod]
        public void GetSettingFolder_CreatesAndReturnsPathUnderAssembly()
        {
            var folder = VCTSettings.GetSettingFolder();
            Assert.IsFalse(string.IsNullOrEmpty(folder));
            Assert.IsTrue(Directory.Exists(folder));
            StringAssert.Contains(folder, VCTSettings.DEFAULT_SETTINGS_FOLDER);
        }

        [TestMethod]
        public void GetSettingsFullPath_EndsWithDefaultFileName()
        {
            var full = VCTSettings.GetSettingsFullPath();
            Assert.IsTrue(full.EndsWith(VCTSettings.DEFAULT_FILE_NAME, StringComparison.OrdinalIgnoreCase));
        }

        [TestMethod]
        public void GetSettingsFullPath_WithEnvOverride_UsesThatAbsolutePath()
        {
            var expected = Path.Combine(Path.GetTempPath(), "vct-env-override-" + Guid.NewGuid().ToString("N") + ".json");
            Environment.SetEnvironmentVariable(VCTSettings.VCT_SETTINGS_FULL_PATH_ENV, expected);
            try
            {
                Assert.AreEqual(expected, VCTSettings.GetSettingsFullPath());
            }
            finally
            {
                Environment.SetEnvironmentVariable(VCTSettings.VCT_SETTINGS_FULL_PATH_ENV, null);
            }
        }

        #endregion

        #region Normalize edge cases

        [TestMethod]
        public void NormalizeWebSocketListenPrefix_EmptyString_UsesDefault()
        {
            Assert.AreEqual(VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX, VCTSettings.NormalizeWebSocketListenPrefix(string.Empty));
        }

        [TestMethod]
        public void NormalizeWebSocketListenPrefix_WhitespaceOnly_UsesDefault()
        {
            Assert.AreEqual(VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX, VCTSettings.NormalizeWebSocketListenPrefix("   "));
        }

        #endregion

        #region Save / Read persistence

        [TestMethod]
        public void Save_DoesNotThrow()
        {
            using (UseIsolatedSettingsFile(out _))
            {
                var settings = VCTSettings.CreateDefaultSettings();
                settings.Save();
            }
        }

        [TestMethod]
        public void Read_AfterSave_RoundTrips()
        {
            using (UseIsolatedSettingsFile(out _))
            {
                VCTSettings.CreateDefaultSettings().Save();
                var loaded = VCTSettings.Read();
                Assert.IsNotNull(loaded);
                Assert.IsNotNull(loaded.Tunnels);
                Assert.IsTrue(loaded.WebSocketListenPrefix.EndsWith("/", StringComparison.Ordinal));
            }
        }

        [TestMethod]
        public void Read_WithMalformedJson_FallsBackToDefaults()
        {
            using (UseIsolatedSettingsFile(out var path))
            {
                File.WriteAllText(path, "{ not valid json");
                var loaded = VCTSettings.Read();
                Assert.IsNotNull(loaded);
                Assert.AreEqual(VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX, loaded.WebSocketListenPrefix);
            }
        }

        [TestMethod]
        public void Read_WithEmptyWebSocketPrefixInFile_AppliesDefaultPrefix()
        {
            using (UseIsolatedSettingsFile(out var path))
            {
                File.WriteAllText(path, "{\"WebSocketListenPrefix\":\"\",\"Tunnels\":[],\"DeviceSettings\":[]}");
                var loaded = VCTSettings.Read();
                Assert.IsNotNull(loaded);
                Assert.AreEqual(VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX, loaded.WebSocketListenPrefix);
            }
        }

        [TestMethod]
        public void Read_WithNonEmptyPrefixMissingTrailingSlash_Normalizes()
        {
            using (UseIsolatedSettingsFile(out var path))
            {
                File.WriteAllText(path, "{\"WebSocketListenPrefix\":\"http://127.0.0.1:9/ws\",\"Tunnels\":[],\"DeviceSettings\":[]}");
                var loaded = VCTSettings.Read();
                Assert.IsNotNull(loaded);
                Assert.AreEqual("http://127.0.0.1:9/ws/", loaded.WebSocketListenPrefix);
            }
        }

        #endregion

        #region Constants Tests

        [TestMethod]
        public void Constants_DefaultFileName_IsVCTJson()
        {
            Assert.AreEqual("VCT.json", VCTSettings.DEFAULT_FILE_NAME);
        }

        [TestMethod]
        public void Constants_DefaultSettingsFolder_IsSettings()
        {
            Assert.AreEqual("Settings", VCTSettings.DEFAULT_SETTINGS_FOLDER);
        }

        #endregion

        /// <summary>Sets <see cref="VCTSettings.VCT_SETTINGS_FULL_PATH_ENV"/> to a unique temp file; deletes that file and sidecar default.json on dispose.</summary>
        private static IDisposable UseIsolatedSettingsFile(out string path)
        {
            path = Path.Combine(Path.GetTempPath(), "vct-test-" + Guid.NewGuid().ToString("N") + ".json");
            Environment.SetEnvironmentVariable(VCTSettings.VCT_SETTINGS_FULL_PATH_ENV, path);
            return new IsolatedSettingsFileScope(path);
        }

        private sealed class IsolatedSettingsFileScope : IDisposable
        {
            private readonly string _path;

            public IsolatedSettingsFileScope(string path)
            {
                _path = path;
            }

            public void Dispose()
            {
                Environment.SetEnvironmentVariable(VCTSettings.VCT_SETTINGS_FULL_PATH_ENV, null);
                TryDelete(_path);
                TryDelete(Path.ChangeExtension(_path, "default.json"));
            }

            private static void TryDelete(string file)
            {
                try
                {
                    if (File.Exists(file))
                        File.Delete(file);
                }
                catch
                {
                }
            }
        }
    }
}
