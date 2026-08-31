using System.Collections.Generic;
using System.Linq;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// MBA-485 — the logger configuration the web app pushes over WebSocket, applied to the
    /// in-memory BL settings.
    ///
    /// This is worth testing precisely because it fails quietly. A channel list that parses wrong
    /// does not throw and does not log: the device simply scans different inputs than the operator
    /// asked for, and the readings look plausible. The parser also has to accept two dialects - the
    /// app sends "0-10 11 20-23", the database column sends "0,1,2" - so it is exactly the kind of
    /// code that drifts.
    ///
    /// Everything here goes through the public ApplyWebSocketConfig rather than reaching for the
    /// private parsers, so the tests keep holding if those are refactored.
    /// </summary>
    [TestClass]
    public class WebSocketLoggerConfigTests
    {
        private const string Master = "21-114";

        private static HardwareBL_Settings SettingsWithMaster(string master = Master)
        {
            var s = new HardwareBL_Settings();
            s.Hydra2type.Masters = new List<string> { master };
            return s;
        }

        #region channel list

        [TestMethod]
        public void AppFormat_RangesAndSingles_ExpandInclusively()
        {
            var s = SettingsWithMaster();

            s.ApplyWebSocketConfig(Master, null, null, "0-3 7 10-11");

            CollectionAssert.AreEqual(new[] { 0, 1, 2, 3, 7, 10, 11 }, s.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void DatabaseFormat_CommaSeparated_IsAccepted()
        {
            // The DB ChannelList column uses commas; the app uses spaces. Both reach this method.
            var s = SettingsWithMaster();

            s.ApplyWebSocketConfig(Master, null, null, "0,1,2");

            CollectionAssert.AreEqual(new[] { 0, 1, 2 }, s.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void OverlappingAndUnorderedInput_ComesBackSortedAndDistinct()
        {
            // A duplicate channel would be scanned twice; unordered input would scan out of sequence.
            var s = SettingsWithMaster();

            s.ApplyWebSocketConfig(Master, null, null, "3,1 1-2 3");

            CollectionAssert.AreEqual(new[] { 1, 2, 3 }, s.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void ReversedRange_IsIgnoredRatherThanInverted()
        {
            var s = SettingsWithMaster();
            s.Hydra2type.Channels = new List<int> { 9 };

            var summary = s.ApplyWebSocketConfig(Master, null, null, "5-2");

            Assert.IsNull(summary, "nothing was applicable, so nothing should be reported as applied");
            CollectionAssert.AreEqual(new[] { 9 }, s.Hydra2type.Channels.ToArray(), "the previous list must survive");
        }

        [TestMethod]
        public void AbsurdlyWideRange_IsRefused()
        {
            // Guards against a typo such as 0-20000 turning into a 20,000-channel scan list.
            var s = SettingsWithMaster();
            s.Hydra2type.Channels = new List<int> { 4 };

            s.ApplyWebSocketConfig(Master, null, null, "0-20000");

            CollectionAssert.AreEqual(new[] { 4 }, s.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void GarbageTokens_AreSkippedWithoutLosingTheGoodOnes()
        {
            var s = SettingsWithMaster();

            s.ApplyWebSocketConfig(Master, null, null, "a b 4 -- 6");

            CollectionAssert.AreEqual(new[] { 4, 6 }, s.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void EmptyChannelList_LeavesTheExistingOneAlone()
        {
            // "no opinion" must not mean "scan nothing".
            var s = SettingsWithMaster();
            s.Hydra2type.Channels = new List<int> { 0, 1 };

            s.ApplyWebSocketConfig(Master, null, null, "   ");

            CollectionAssert.AreEqual(new[] { 0, 1 }, s.Hydra2type.Channels.ToArray());
        }

        [TestMethod]
        public void NegativeChannel_IsAcceptedToday()
        {
            // Pinning CURRENT behaviour, not endorsing it: "-5" has its dash at index 0, so it is not
            // treated as a range and falls through to a plain parse. A negative channel index is
            // meaningless to every device here. Left as-is because tightening it is a behaviour
            // change that belongs in its own ticket, but it should not change unnoticed.
            var s = SettingsWithMaster();

            s.ApplyWebSocketConfig(Master, null, null, "-5 2");

            CollectionAssert.AreEqual(new[] { -5, 2 }, s.Hydra2type.Channels.ToArray());
        }

        #endregion

        #region rate

        [TestMethod]
        public void Rate_AcceptsHebrewAndEnglish_EitherCase()
        {
            foreach (var fast in new[] { "מהיר", "fast", "FAST", " Fast " })
            {
                var s = SettingsWithMaster();
                s.ApplyWebSocketConfig(Master, fast, null, null);
                Assert.AreEqual(HardwareBL_DeviceType.MeasurementRates.FAST, s.Hydra2type.MeasurementRate, fast);
            }

            foreach (var slow in new[] { "איטי", "slow", "SLOW" })
            {
                var s = SettingsWithMaster();
                s.Hydra2type.MeasurementRate = HardwareBL_DeviceType.MeasurementRates.FAST;
                s.ApplyWebSocketConfig(Master, slow, null, null);
                Assert.AreEqual(HardwareBL_DeviceType.MeasurementRates.SLOW, s.Hydra2type.MeasurementRate, slow);
            }
        }

        [TestMethod]
        public void UnrecognisedRate_LeavesTheCurrentOne()
        {
            var s = SettingsWithMaster();
            s.Hydra2type.MeasurementRate = HardwareBL_DeviceType.MeasurementRates.FAST;

            var summary = s.ApplyWebSocketConfig(Master, "medium", null, null);

            Assert.IsNull(summary);
            Assert.AreEqual(HardwareBL_DeviceType.MeasurementRates.FAST, s.Hydra2type.MeasurementRate);
        }

        #endregion

        #region interval

        [TestMethod]
        public void Interval_MustBePositive()
        {
            var s = SettingsWithMaster();
            s.Hydra2type.Interval = 7;

            foreach (var bad in new[] { "0", "-3", "abc", "" })
            {
                s.ApplyWebSocketConfig(Master, null, bad, null);
                Assert.AreEqual(7, s.Hydra2type.Interval, "interval should have been rejected: '" + bad + "'");
            }

            s.ApplyWebSocketConfig(Master, null, " 12 ", null);
            Assert.AreEqual(12, s.Hydra2type.Interval);
        }

        #endregion

        #region routing to a family

        [TestMethod]
        public void UnknownLogger_ChangesNothingAndSaysSo()
        {
            var s = SettingsWithMaster();
            s.Hydra2type.Interval = 3;

            var summary = s.ApplyWebSocketConfig("not-a-master", "fast", "9", "0-5");

            Assert.IsNull(summary);
            Assert.AreEqual(3, s.Hydra2type.Interval, "a configuration for someone else must not land here");
        }

        [TestMethod]
        public void MasterMatch_IgnoresCaseAndSurroundingSpace()
        {
            // Masters come from a settings file people edit by hand, so both are realistic.
            var s = SettingsWithMaster("  ab-12  ");

            var summary = s.ApplyWebSocketConfig("AB-12", null, "4", null);

            Assert.IsNotNull(summary);
            Assert.AreEqual(4, s.Hydra2type.Interval);
        }

        [TestMethod]
        public void EmptyLoggerId_IsRejected()
        {
            var s = SettingsWithMaster();

            Assert.IsNull(s.ApplyWebSocketConfig(null, "fast", "5", "0-2"));
            Assert.IsNull(s.ApplyWebSocketConfig("   ", "fast", "5", "0-2"));
        }

        [TestMethod]
        public void OnlyTheMatchingFamilyIsTouched()
        {
            var s = SettingsWithMaster();
            s.Agilent.Interval = 99;
            s.Agilent.Masters = new List<string> { "other" };

            s.ApplyWebSocketConfig(Master, null, "6", null);

            Assert.AreEqual(6, s.Hydra2type.Interval);
            Assert.AreEqual(99, s.Agilent.Interval, "a sibling family must not be reconfigured");
        }

        [TestMethod]
        public void SummaryNamesTheFamilyAndWhatChanged()
        {
            // The summary is what goes to the log; it is the only trace an operator has that their
            // configuration arrived.
            var s = SettingsWithMaster();

            var summary = s.ApplyWebSocketConfig(Master, "fast", "5", "0-2");

            StringAssert.Contains(summary, "Hydra2");
            StringAssert.Contains(summary, Master);
            StringAssert.Contains(summary, "rate=FAST");
            StringAssert.Contains(summary, "interval=5");
            StringAssert.Contains(summary, "channels=[0,1,2]");
        }

        #endregion
    }
}
