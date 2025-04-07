using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class LoggerConfig
    {
        public string LoggerId { get; set; }
        public string IP { get; set; }
        public string Rate { get; set; }
        public string Interval { get; set; }
        public string BatchId { get; set; }
        public string BatchChannels { get; set; }
    }
}
