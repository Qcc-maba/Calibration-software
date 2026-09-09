using System;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for HP 53181A replies.
    /// Kept separate from <see cref="Hp53181aBL"/> so the logic is unit-testable.
    /// </summary>
    public static class Hp53181aReadings
    {
        /// <summary>Channel 1 is the 225 MHz input; channel 2 is the optional high-frequency one.</summary>
        public const int MeasurementInputCount = 2;

        private const double NoResultThreshold = 9.0e37;

        /// <summary>
        /// Peak input voltage below which the input is treated as unconnected. Measured on an open
        /// input: +0.0E-001. The same guard the CNT-90 needs, for the same reason — see
        /// <see cref="Cnt90Readings.SignalPresentThresholdVolts"/>.
        /// </summary>
        public const double SignalPresentThresholdVolts = 0.05;

        /// <summary>True when the reply is not a usable reading and must not be broadcast.</summary>
        public static bool IsNoResult(double raw)
        {
            return double.IsNaN(raw) || double.IsInfinity(raw) || Math.Abs(raw) >= NoResultThreshold;
        }

        /// <summary>True when <paramref name="channel"/> is a measurement input this model has.</summary>
        public static bool IsValidChannel(int channel)
        {
            return channel >= 1 && channel <= MeasurementInputCount;
        }

        /// <summary>
        /// True when a peak-voltage reading indicates something is actually connected.
        /// <para>
        /// This guard is what keeps the counter from wedging a session: with an open input a frequency
        /// measurement waits for edges that never arrive and never answers (measured: still nothing
        /// after 10 s), while a voltage query answers in well under a second either way.
        /// </para>
        /// </summary>
        public static bool IndicatesSignalPresent(double peakVolts)
        {
            return !IsNoResult(peakVolts) && Math.Abs(peakVolts) >= SignalPresentThresholdVolts;
        }

        /// <summary>
        /// Parses a 53181A numeric reply. The counter answers in a padded scientific form
        /// ("+1.00000E+006", "+0.0E-001"). Returns false rather than a default so an unparsable reply
        /// cannot be broadcast as a reading of 0.
        /// </summary>
        public static bool TryParseValue(string reply, out double value)
        {
            value = 0;
            if (string.IsNullOrEmpty(reply))
                return false;

            var text = reply.Replace("\r", "").Replace("\n", "").Trim();
            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
        }

        /// <summary>
        /// True when a <c>:SYST:ERR?</c> reply reports no error. Unlike the CNT-90, this counter has a
        /// real SCPI error queue, so a command can actually be checked.
        /// </summary>
        public static bool IsNoError(string systemErrorReply)
        {
            if (string.IsNullOrEmpty(systemErrorReply))
                return false;

            var text = systemErrorReply.Trim();
            return text.StartsWith("+0,") || text.StartsWith("0,");
        }
    }
}
