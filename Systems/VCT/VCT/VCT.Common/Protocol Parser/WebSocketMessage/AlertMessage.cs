using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class AlertMessage : BaseMessage
    {
        [JsonPropertyName("message")]
        public string Message { get; set; }
    }

}
