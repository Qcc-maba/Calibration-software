using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class LoggerDataMessage : BaseMessage
    {
        public string DeviceId { get; set; }
        public string LoggerId { get; set; }
        public string BatchId { get; set; }
        public DateTime Time { get; set; }
        public Dictionary<string, string> ChannelValues { get; set; }
    }
}
