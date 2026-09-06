using System;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for Keysight EDUX1002A :MEASure? replies.
    /// Kept separate from <see cref="KeysightEdux1002aBL"/> so the logic is unit-testable.
    /// </summary>
    public static class KeysightEdux1002aReadings
    {
        /// <summary>The EDUX1002A has two analog channels (50 MHz, 1 GSa/s).</summary>
        public const int AnalogChannelCount = 2;

        /// <summary>
        /// The scope returns +9.9E+37 when a measurement cannot be made — typically because the
        /// portion of the waveform the measurement needs is not on screen (Programmer's Guide,
        /// ":MEASure Commands" &gt; "Measurement Error"). It is a sentinel, not a reading.
        /// </summary>
        public const double MeasurementErrorValue = 9.9e37;

        /// <summary>
        /// Guard band below the sentinel. Anything at or above this magnitude is treated as
        /// "no measurement" so that round-tripping through double never lets +9.9E+37 through.
        /// </summary>
        private const double MeasurementErrorThreshold = 9.0e37;

        /// <summary>
        /// True when the reply is the "cannot measure" sentinel (or otherwise not a finite number),
        /// in which case it must not be broadcast — a scope with no signal on screen would
        /// otherwise flood the app with 9.9E+37 or 0.
        /// </summary>
        public static bool IsMeasurementError(double raw)
        {
            return double.IsNaN(raw) || double.IsInfinity(raw) || Math.Abs(raw) >= MeasurementErrorThreshold;
        }

        /// <summary>True when <paramref name="channel"/> is an analog channel this model actually has.</summary>
        public static bool IsValidChannel(int channel)
        {
            return channel >= 1 && channel <= AnalogChannelCount;
        }
    }
}
