using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class SensorsAssociationMessage : BaseMessage
    {
        public string DeviceId { get; set; }
        public string LoggerId { get; set; }
        public string BatchId { get; set; }
        public string BatchChannels { get; set; }
        public string Units { get; set; }
        public string Resolution { get; set; }
        public bool SendData { get; set; }
    }

}
