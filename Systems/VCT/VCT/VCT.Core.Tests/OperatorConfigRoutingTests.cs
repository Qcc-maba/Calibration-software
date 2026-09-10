using System;
using Maba.VCT.Core.Settings;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-962: the calibrator picks the logger, its rate and its channels on the configuration
    /// screen, and the app sends that logger's MABA id over the WebSocket. The server used to accept
    /// the message only if that id was already listed in HydraBL_Settings.json's Masters - a list
    /// written by hand, naming one bench logger. On every other station the message was dropped in
    /// silence and the device kept the file's twenty channels, which is also what made start-up take
    /// about a minute at two seconds per channel.
    /// </summary>
    [TestClass]
    public class OperatorConfigRoutingTests
    {
        private HardwareBL_Settings _settings;

        [TestInitialize]
        public void Setup()
        {
            foreach (var f in HardwareBL_Settings.ActiveFamilies())
                HardwareBL_Settings.UnregisterActiveFamily(f);

            HardwareBL_Settings._settings = HardwareBL_Settings.CreateDefaultSettings();
            _settings = HardwareBL_Settings._settings;
            _settings.Hydra2type.Masters = new System.Collections.Generic.List<string> { "21-449" };
            _settings.Hydra2type.Channels = new System.Collections.Generic.List<int> { 1, 2, 3, 4, 5 };
        }

        [TestCleanup]
        public void Cleanup()
        {
            foreach (var f in HardwareBL_Settings.ActiveFamilies())
                HardwareBL_Settings.UnregisterActiveFamily(f);
            HardwareBL_Settings._settings = null;
        }

        [TestMethod]
        public void AKnownLoggerIdStillMatchesThroughMasters()
        {
            var summary = _settings.ApplyWebSocketConfig("21-449", null, null, "3,4");

            Assert.IsNotNull(summary);
            CollectionAssert.AreEqual(new[] { 3, 4 }, _settings.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void AnUnknownLoggerIdIsRoutedToTheOnlyLiveFamily()
        {
            // The station's file names 21-449; the logger actually on this bench is a different one.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");

            var summary = _settings.ApplyWebSocketConfig("21-701", null, null, "7,8,9");

            Assert.IsNotNull(summary, "the operator's channels were dropped because of a list they never wrote");
            StringAssert.Contains(summary, "live device");
            CollectionAssert.AreEqual(new[] { 7, 8, 9 }, _settings.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void WithNoLiveDeviceNothingIsGuessed()
        {
            var summary = _settings.ApplyWebSocketConfig("21-701", null, null, "7,8");

            Assert.IsNull(summary);
            CollectionAssert.AreEqual(new[] { 1, 2, 3, 4, 5 }, _settings.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void WithTwoLiveFamiliesNothingIsGuessed()
        {
            // Two loggers connected: there is no honest way to tell which one the message is about,
            // and configuring the wrong instrument is worse than configuring none.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            HardwareBL_Settings.RegisterActiveFamily("Hydra3");

            var summary = _settings.ApplyWebSocketConfig("21-701", null, null, "7,8");

            Assert.IsNull(summary);
            CollectionAssert.AreEqual(new[] { 1, 2, 3, 4, 5 }, _settings.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void TheFallbackDoesNotTouchMasters()
        {
            // Masters selects which correction curves a reading gets. A channel list must never
            // change that quietly.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");

            _settings.ApplyWebSocketConfig("21-701", null, null, "7,8");

            CollectionAssert.AreEqual(new[] { "21-449" }, _settings.Hydra2type.Masters.ToArray());
        }

        [TestMethod]
        public void RegisteringTheSameFamilyTwiceLeavesOneEntry()
        {
            // OnCreateStates runs again on every re-initialisation, including power-cycle recovery.
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");
            HardwareBL_Settings.RegisterActiveFamily("Hydra2");

            Assert.AreEqual(1, HardwareBL_Settings.ActiveFamilies().Count,
                            "a second registration would look like a second logger and disable the fallback");
        }
    }

    /// <summary>
    /// MBA-962 — the device tick. One command goes out per tick, so the tick is what start-up costs:
    /// a Hydra told to configure twenty channels spent forty seconds on FUNC commands alone before
    /// it could be told to scan.
    /// </summary>
    [TestClass]
    public class ServerTimerIntervalTests
    {
        [TestMethod]
        public void TheOldHardCodedValueIsMigrated()
        {
            // Every station's VCT.json says 2000 because Save() wrote the old getter's value there,
            // not because anyone chose it - and the installer does not overwrite that file.
            Assert.AreEqual(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL,
                            VCTSettings.NormalizeServerTimerInterval(VCTSettings.LEGACY_SERVER_TIMER_INTERVAL));
        }

        [TestMethod]
        public void ADeliberateValueIsKept()
        {
            Assert.AreEqual(250, VCTSettings.NormalizeServerTimerInterval(250));
            Assert.AreEqual(1999, VCTSettings.NormalizeServerTimerInterval(1999));
            Assert.AreEqual(2001, VCTSettings.NormalizeServerTimerInterval(2001));
        }

        [TestMethod]
        public void NonsenseIsRefusedRatherThanObeyed()
        {
            // 5 would spin the tick; 50000 would be indistinguishable from a hung server.
            Assert.AreEqual(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL, VCTSettings.NormalizeServerTimerInterval(5));
            Assert.AreEqual(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL, VCTSettings.NormalizeServerTimerInterval(0));
            Assert.AreEqual(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL, VCTSettings.NormalizeServerTimerInterval(-1));
            Assert.AreEqual(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL, VCTSettings.NormalizeServerTimerInterval(50000));
        }

        [TestMethod]
        public void TheDefaultIsFasterThanTheValueItReplaces()
        {
            Assert.IsTrue(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL < VCTSettings.LEGACY_SERVER_TIMER_INTERVAL);
            Assert.AreEqual(VCTSettings.DEFAULT_SERVER_TIMER_INTERVAL, new VCTSettings().ServerTimerInterval);
        }
    }
}
