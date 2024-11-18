using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;

namespace Maba.Connectors.AWS.SQS
{
    public class MessageRequest
    {
        public string MessageId { get; set; }
        public object Body { get; set; }
        public bool Valid { get; set; }
        public HttpStatusCode Code { set; get; }
    }
}
