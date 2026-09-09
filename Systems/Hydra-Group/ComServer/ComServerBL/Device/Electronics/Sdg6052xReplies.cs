using System;
using System.Collections.Generic;
using System.Globalization;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) parsing for Siglent SDG6052X replies.
    /// <para>
    /// The SDG does not answer like the SCPI instruments in this repo. A reply echoes the command
    /// header and glues the unit onto every number:
    /// </para>
    /// <code>
    /// C1:BSWV?  ->  C1:BSWV WVTP,SINE,FRQ,1000HZ,PERI,0.001S,AMP,4V,AMPVRMS,1.414Vrms,OFST,0V,...
    /// C1:OUTP?  ->  C1:OUTP OFF,LOAD,HZ,PLRT,NOR
    /// </code>
    /// <para>
    /// So <c>double.Parse("1000HZ")</c> throws, and none of the numeric paths used for the SCPI
    /// instruments can read these. Everything the BL needs to understand an SDG reply lives here.
    /// </para>
    /// </summary>
    public static class Sdg6052xReplies
    {
        /// <summary>The generator's two output channels.</summary>
        public const int OutputChannelCount = 2;

        /// <summary>True when <paramref name="channel"/> is an output this model has.</summary>
        public static bool IsValidChannel(int channel)
        {
            return channel >= 1 && channel <= OutputChannelCount;
        }

        /// <summary>
        /// Strips the echoed header ("C1:BSWV ", "C2:OUTP ") from a reply, leaving the payload.
        /// Returns the input unchanged when there is no header, so the parser also copes with a unit
        /// whose COMM_HEADER is switched off.
        /// </summary>
        public static string StripHeader(string reply)
        {
            if (string.IsNullOrEmpty(reply))
                return "";

            var text = reply.Replace("\r", "").Replace("\n", "").Trim();

            // A header is "<channel>:<command> " - take everything after the first space that follows
            // a colon, and only when the colon really precedes that space.
            var space = text.IndexOf(' ');
            if (space > 0 && text.LastIndexOf(':', space) > 0)
                return text.Substring(space + 1).Trim();

            return text;
        }

        /// <summary>
        /// Splits a payload into its key/value pairs. The SDG emits a flat comma-separated list where
        /// keys and values alternate ("WVTP,SINE,FRQ,1000HZ,..."), so a trailing key with no value is
        /// dropped rather than paired with nothing.
        /// </summary>
        public static Dictionary<string, string> ParseParameters(string reply)
        {
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var payload = StripHeader(reply);
            if (payload.Length == 0)
                return result;

            var parts = payload.Split(',');
            for (int i = 0; i + 1 < parts.Length; i += 2)
            {
                var key = parts[i].Trim();
                if (key.Length == 0)
                    continue;
                result[key] = parts[i + 1].Trim();
            }
            return result;
        }

        /// <summary>
        /// Reads a numeric parameter, discarding the unit suffix the SDG appends ("1000HZ" -> 1000,
        /// "4V" -> 4, "1.414Vrms" -> 1.414, "0.001S" -> 0.001). Returns false when the key is absent
        /// or the value is not a number, so a missing reading is never mistaken for zero.
        /// </summary>
        public static bool TryGetNumeric(IDictionary<string, string> parameters, string key, out double value)
        {
            value = 0;
            string raw;
            if (parameters == null || !parameters.TryGetValue(key, out raw))
                return false;

            return TryParseNumber(raw, out value);
        }

        /// <summary>
        /// Parses one SDG number, tolerating the glued-on unit. Keeps the leading sign, digits, decimal
        /// point and any exponent, and stops at the first character that cannot belong to the number.
        /// </summary>
        public static bool TryParseNumber(string raw, out double value)
        {
            value = 0;
            if (string.IsNullOrEmpty(raw))
                return false;

            var text = raw.Trim();
            int end = 0;
            while (end < text.Length)
            {
                var c = text[end];
                bool isNumeric = char.IsDigit(c)
                              || (end == 0 && (c == '+' || c == '-'))
                              || c == '.'
                              // An exponent, but not the 'E' that starts a unit like "Erms".
                              || ((c == 'e' || c == 'E') && end + 1 < text.Length
                                  && (char.IsDigit(text[end + 1]) || text[end + 1] == '+' || text[end + 1] == '-'))
                              || ((c == '+' || c == '-') && end > 0
                                  && (text[end - 1] == 'e' || text[end - 1] == 'E'));
                if (!isNumeric)
                    break;
                end++;
            }

            if (end == 0)
                return false;

            return double.TryParse(text.Substring(0, end), NumberStyles.Float,
                                   CultureInfo.InvariantCulture, out value);
        }

        /// <summary>
        /// True when an output-state reply says the channel is energised. The state is the first
        /// value in the payload ("OFF,LOAD,HZ,PLRT,NOR"), not a key/value pair, so it is read
        /// positionally.
        /// </summary>
        public static bool IsOutputOn(string outputReply)
        {
            var payload = StripHeader(outputReply);
            if (payload.Length == 0)
                return false;

            var first = payload.Split(',')[0].Trim();
            return string.Equals(first, "ON", StringComparison.OrdinalIgnoreCase);
        }
    }
}
