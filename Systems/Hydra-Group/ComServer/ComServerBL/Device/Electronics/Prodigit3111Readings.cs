using System;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for PRODIGIT 3111 replies.
    /// Kept separate from <see cref="Prodigit3111BL"/> so the logic is unit-testable.
    /// </summary>
    public static class Prodigit3111Readings
    {
        /// <summary>Single-input load: there is only one measurement channel.</summary>
        public const int MeasurementChannel = 1;

        /// <summary>
        /// The value <c>ERR?</c> answered throughout mapping. It never changed - not after a good
        /// command, not after a deliberately bogus one, and reading it did not clear it - so it is a
        /// fixed status word, not an error queue.
        /// </summary>
        public const int ConstantErrorReply = 21;

        /// <summary>
        /// Rated maxima (80 V / 70 A / 350 W). A reply beyond these is not a reading this instrument
        /// can produce, so it is rejected rather than broadcast.
        /// </summary>
        public const double MaxVolts = 80.0;
        public const double MaxAmps = 70.0;
        public const double MaxWatts = 350.0;

        /// <summary>
        /// Parses a measurement reply. The load answers a signed fixed-point value ("+0.0000",
        /// "-0.0000"); returns false rather than a default so an unparsable reply cannot be
        /// broadcast as a reading of 0 - which on this instrument is also a perfectly plausible
        /// real measurement, and therefore indistinguishable after the fact.
        /// </summary>
        public static bool TryParseMeasurement(string reply, out double value)
        {
            value = 0;
            if (string.IsNullOrEmpty(reply))
                return false;

            var text = reply.Replace("\r", "").Replace("\n", "").Trim();
            if (text.Length == 0)
                return false;

            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
        }

        /// <summary>
        /// True when the load's input is armed. <c>LOAD?</c> answers "0" when off. The BL reports this
        /// but never changes it.
        /// </summary>
        public static bool IsLoadOn(string loadStateReply)
        {
            double state;
            return TryParseMeasurement(loadStateReply, out state) && Math.Abs(state) > 0.5;
        }

        /// <summary>True when a reading is within what this model can actually measure.</summary>
        public static bool IsPlausible(double value, double ratedMaximum)
        {
            return !double.IsNaN(value) && !double.IsInfinity(value)
                && Math.Abs(value) <= ratedMaximum;
        }

        /// <summary>The rated maximum for the quantity a measurement query asked about.</summary>
        public static double RatedMaximumFor(Settings.SensorType sensor)
        {
            if (sensor == null)
                return MaxVolts;

            switch (sensor.MeasureType)
            {
                case Settings.SensorType.MeasureTypes.Current: return MaxAmps;
                case Settings.SensorType.MeasureTypes.Power: return MaxWatts;
                default: return MaxVolts;
            }
        }
    }
}
