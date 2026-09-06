using System;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for Fluke 5322A replies.
    /// Kept separate from <see cref="Fluke5322aBL"/> so the logic is unit-testable.
    /// <para>
    /// Reply shapes are taken from the Operators Manual and are NOT yet confirmed against hardware.
    /// </para>
    /// </summary>
    public static class Fluke5322aReadings
    {
        // Identification lives with the other model-matching helpers in HardwareDeviceHost
        // (IsFluke5322a), next to the branch that uses it - not here - so there is one place that
        // decides which instrument a reply names.

        /// <summary>
        /// Parses a numeric reply. The 5322A returns setpoints in exponential form — the manual's own
        /// example is 50.54 mOhm returned as <c>50.54e-03</c>.
        /// <para>
        /// Returns false rather than a default, so a reply that cannot be read is never mistaken for
        /// a genuine zero setpoint — a perfectly plausible value on a calibrator, and therefore
        /// indistinguishable from a parse failure once the two are conflated.
        /// </para>
        /// </summary>
        public static bool TryParseValue(string reply, out double value)
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
        /// True when <c>OUTP?</c> reports the output signal is applied to the terminals. The command
        /// takes ON / OFF and 0 / 1, so both spellings are read back.
        /// </summary>
        public static bool IsOutputLive(string outputReply)
        {
            if (string.IsNullOrEmpty(outputReply))
                return false;

            var text = outputReply.Replace("\r", "").Replace("\n", "").Trim();
            if (text.Equals("ON", StringComparison.OrdinalIgnoreCase))
                return true;
            if (text.Equals("OFF", StringComparison.OrdinalIgnoreCase))
                return false;

            double state;
            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out state)
                && Math.Abs(state) > 0.5;
        }

        /// <summary>
        /// Normalises a <c>SAF:MODE?</c> reply. The 5322A answers one of the electrical-safety
        /// functions { GBR | GBOP | HRES | HRF | HRSH | LRES | LROP | LRSH | IDAC | IDS | IDSS |
        /// IDSO | IDP | IDD | RCDT | RCDC | RCDP | LIN | LOOP | VOLT | MET | HIPL | HIPT | FLI |
        /// FLII }. An unreadable reply comes back as an empty string.
        /// </summary>
        public static string NormalizeMode(string modeReply)
        {
            if (string.IsNullOrEmpty(modeReply))
                return string.Empty;

            return modeReply.Replace("\r", "").Replace("\n", "").Trim().ToUpperInvariant();
        }

        /// <summary>
        /// The broadcast unit implied by a <c>SAF:MODE?</c> function. The 5322A's functions are
        /// mostly resistance and leakage-current simulations, so an unrecognised mode falls back to
        /// resistance rather than to voltage: ground bond and the two resistance modes are what this
        /// instrument spends nearly all its time in.
        /// </summary>
        public static string UnitsForMode(string modeReply)
        {
            switch (NormalizeMode(modeReply))
            {
                case "VOLT":
                case "MET":
                    return Settings.HardwareBL_Settings.Units_Voltage;

                case "IDAC":
                case "IDS":
                case "IDSS":
                case "IDSO":
                case "IDP":
                case "IDD":
                case "RCDC":
                case "HIPL":
                    return Settings.HardwareBL_Settings.Units_Current;

                // RCD trip time and the hipot/flash timers are seconds - a quantity the broadcast
                // vocabulary has no name for, so they keep the instrument's own reading unlabelled
                // rather than being relabelled as something they are not.
                case "RCDT":
                case "RCDP":
                case "HIPT":
                    return string.Empty;

                default:
                    return Settings.HardwareBL_Settings.Units_Resistance;
            }
        }
    }
}
