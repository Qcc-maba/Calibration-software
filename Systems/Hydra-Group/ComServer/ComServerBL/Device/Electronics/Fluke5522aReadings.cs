using System;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for Fluke 5522A replies.
    /// Kept separate from <see cref="Fluke5522aBL"/> so the logic is unit-testable.
    /// </summary>
    public static class Fluke5522aReadings
    {
        /// <summary>
        /// Shape of an <c>OUT?</c> reply, verified live:
        /// <c>0.0000000E+00,V,0E+00,0,0.00E+00</c> —
        /// primary amplitude, primary unit, secondary amplitude, secondary unit, frequency.
        /// </summary>
        public sealed class OutputSetting
        {
            public double Amplitude { get; set; }
            public string Unit { get; set; }
            public double Frequency { get; set; }
        }

        /// <summary>
        /// Parses an <c>OUT?</c> reply. Returns false rather than a default, so a reply that cannot be
        /// read is never mistaken for a genuine 0 V setpoint — which on a calibrator is a perfectly
        /// plausible value and therefore indistinguishable after the fact.
        /// </summary>
        public static bool TryParseOutput(string reply, out OutputSetting setting)
        {
            setting = null;
            if (string.IsNullOrEmpty(reply))
                return false;

            var text = reply.Replace("\r", "").Replace("\n", "").Trim();
            var parts = text.Split(',');
            if (parts.Length < 2)
                return false;

            double amplitude;
            if (!double.TryParse(parts[0].Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out amplitude))
                return false;

            // The frequency is the last field; absent or unparsable means dc, which the 5522A reports
            // as 0 rather than omitting the field.
            double frequency = 0;
            if (parts.Length >= 5)
                double.TryParse(parts[4].Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out frequency);

            setting = new OutputSetting
            {
                Amplitude = amplitude,
                Unit = parts[1].Trim(),
                Frequency = frequency
            };
            return true;
        }

        /// <summary>
        /// True when <c>OPER?</c> reports the output terminals are live. "0" is standby — the state
        /// the instrument powers up in, and the only state this BL ever leaves it in.
        /// </summary>
        public static bool IsOutputLive(string operateReply)
        {
            if (string.IsNullOrEmpty(operateReply))
                return false;

            var text = operateReply.Replace("\r", "").Replace("\n", "").Trim();
            double state;
            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out state)
                && Math.Abs(state) > 0.5;
        }

        /// <summary>
        /// True when an <c>ERR?</c> reply reports no error. The 5522A answers
        /// <c>0,"No Error"</c> when the queue is empty.
        /// </summary>
        public static bool IsNoError(string errorReply)
        {
            if (string.IsNullOrEmpty(errorReply))
                return false;

            return errorReply.Trim().StartsWith("0,");
        }

        /// <summary>
        /// The unit the 5522A reports for a setpoint, mapped to the vocabulary the rest of the server
        /// broadcasts. Anything unrecognised keeps the instrument's own spelling rather than being
        /// silently relabelled.
        /// </summary>
        public static string NormalizeUnit(string flukeUnit)
        {
            if (string.IsNullOrEmpty(flukeUnit))
                return Settings.HardwareBL_Settings.Units_Voltage;

            switch (flukeUnit.Trim().ToUpperInvariant())
            {
                case "V": return Settings.HardwareBL_Settings.Units_Voltage;
                case "A": return Settings.HardwareBL_Settings.Units_Current;
                case "OHM": return Settings.HardwareBL_Settings.Units_Resistance;
                case "HZ": return Settings.HardwareBL_Settings.Units_Frequency;
                case "CEL": return Settings.HardwareBL_Settings.Units_Temperature;
                default: return flukeUnit.Trim();
            }
        }
    }
}
