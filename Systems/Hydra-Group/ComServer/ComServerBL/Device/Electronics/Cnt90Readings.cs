using System;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for Pendulum CNT-90 replies.
    /// Kept separate from <see cref="Cnt90BL"/> so the logic is unit-testable.
    /// </summary>
    public static class Cnt90Readings
    {
        /// <summary>Measurement inputs A and B. (@3) is the optional prescaler and (@4) the rear arming input.</summary>
        public const int MeasurementInputCount = 2;

        /// <summary>
        /// The counter's "no valid result" value. It is only ever produced in COMPatible (53131/53132)
        /// mode - in the NATive mode this BL uses, a measurement that cannot complete blocks instead of
        /// answering. Guarded anyway so the value can never reach the app as a reading.
        /// </summary>
        public const double NoResultValue = 9.91e37;

        private const double NoResultThreshold = 9.0e37;

        /// <summary>
        /// Peak input voltage below which the input is treated as unconnected. An open input reads a
        /// few millivolts of noise (measured: -4 mV to -2 mV); a real signal is orders of magnitude
        /// larger. Used to decide whether it is safe to issue a frequency query at all.
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
        /// True when a peak-voltage reading indicates something is actually connected to the input.
        /// <para>
        /// This is the guard that keeps the counter from wedging a session: with an open input a
        /// frequency measurement waits for edges that never arrive and never answers, so the BL asks
        /// this cheap question first (a voltage query answers in a few hundred ms regardless).
        /// </para>
        /// </summary>
        public static bool IndicatesSignalPresent(double peakVolts)
        {
            return !IsNoResult(peakVolts) && Math.Abs(peakVolts) >= SignalPresentThresholdVolts;
        }

        /// <summary>
        /// Parses a CNT-90 numeric reply (NR3, e.g. "+1.0000000000000E+07"). Returns false rather than
        /// a default so an unparsable reply cannot be broadcast as a reading of 0.
        /// </summary>
        public static bool TryParseValue(string reply, out double value)
        {
            value = 0;
            if (string.IsNullOrEmpty(reply))
                return false;

            var text = reply.Replace("\r", "").Replace("\n", "").Trim();
            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
        }
    }
}
