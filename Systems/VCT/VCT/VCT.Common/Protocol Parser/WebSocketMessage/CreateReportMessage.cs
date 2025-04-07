using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class CreateReportMessage : BaseMessage
    {
        public string DeviceId { get; set; }
    }
}
