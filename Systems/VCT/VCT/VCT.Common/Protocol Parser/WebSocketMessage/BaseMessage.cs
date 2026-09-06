using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class BaseMessage : IPacket
    {
        [JsonPropertyName("CMD")]
        public string Command { get; set; }

        /*  The signed-in calibrator, carried on ANY message rather than on a login command of its
            own. The ComServer cannot discover who is signed in - it starts before anyone signs in
            and is a different process from the browser - so the web app announces it, and it is
            accepted from whichever message happens to arrive first. Optional: messages without it
            behave exactly as before. See CalibratorSession. */
        [JsonPropertyName("Email")]
        public string Email { get; set; }
    }
}
