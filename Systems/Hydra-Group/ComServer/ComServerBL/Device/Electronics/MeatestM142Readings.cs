using System;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for Meatest M-142 replies.
    /// Kept separate from <see cref="MeatestM142BL"/> so the logic is unit-testable.
    /// <para>
    /// Reply shapes are taken from the official manual and are NOT yet confirmed against hardware.
    /// </para>
    /// </summary>
    public static class MeatestM142Readings
    {
        /// <summary>The M-142 reports "no measurement mode selected" as this token.</summary>
        public const string MeterOff = "OFF";

        /// <summary>
        /// Parses a numeric reply. The M-142 answers <c>MEAS?</c> in exponential form — the manual's
        /// own example is 20.5 returned as <c>2.050000e+001</c> — and the source setpoint queries use
        /// the same format.
        /// <para>
        /// Returns false rather than a default: on an instrument that can legitimately be set to
        /// 0 V, a failed parse and a genuine zero are indistinguishable once conflated.
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

            // Tolerate a unit glued to the number the way the Siglent generator does it; the manual
            // does not document one here, but discarding a trailing non-numeric tail costs nothing.
            int end = 0;
            while (end < text.Length && (char.IsDigit(text[end]) || text[end] == '+' || text[end] == '-'
                                         || text[end] == '.' || text[end] == 'e' || text[end] == 'E'))
                end++;
            if (end == 0)
                return false;

            return double.TryParse(text.Substring(0, end), NumberStyles.Float,
                                   CultureInfo.InvariantCulture, out value);
        }

        /// <summary>
        /// True when <c>OUTP?</c> reports the output terminals are connected. The M-142 answers the
        /// words ON / OFF, but the command also accepts 0 / 1, so both spellings are read.
        /// <para>
        /// ⚠️ With the 50-turn coil option selected (<c>OUTP:ISEL HI50</c>) "live" here means up to
        /// 1000 A through the coil.
        /// </para>
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
        /// Normalises a <c>MEAS:CONF?</c> reply to the manual's own vocabulary
        /// { VOLT | CURR | MVOLT | RES | FREQ | TEMPERATURE:RTD | TEMPERATURE:THERMOCOUPLE | OFF }.
        /// An unreadable reply is reported as <see cref="MeterOff"/>, so the BL falls back to the
        /// source setpoint instead of broadcasting a measurement it cannot vouch for.
        /// </summary>
        public static string NormalizeMeterMode(string configReply)
        {
            if (string.IsNullOrEmpty(configReply))
                return MeterOff;

            var text = configReply.Replace("\r", "").Replace("\n", "").Trim().ToUpperInvariant();
            return text.Length == 0 ? MeterOff : text;
        }

        /// <summary>True when the internal multimeter is not measuring anything.</summary>
        public static bool IsMeterOff(string configReply)
        {
            return NormalizeMeterMode(configReply) == MeterOff;
        }

        /// <summary>
        /// The broadcast unit implied by a <c>MEAS:CONF?</c> mode. MVOLT is millivolts but is still
        /// reported in the Volt vocabulary — the value itself carries the scale, and inventing a
        /// second voltage unit would split one quantity across two names downstream.
        /// </summary>
        public static string UnitsForMeterMode(string configReply)
        {
            var mode = NormalizeMeterMode(configReply);

            if (mode.StartsWith("TEMP", StringComparison.Ordinal))
                return Settings.HardwareBL_Settings.Units_Temperature;

            switch (mode)
            {
                case "CURR": return Settings.HardwareBL_Settings.Units_Current;
                case "RES": return Settings.HardwareBL_Settings.Units_Resistance;
                case "FREQ": return Settings.HardwareBL_Settings.Units_Frequency;
                case "VOLT":
                case "MVOLT": return Settings.HardwareBL_Settings.Units_Voltage;
                default: return Settings.HardwareBL_Settings.Units_Voltage;
            }
        }
    }
}
