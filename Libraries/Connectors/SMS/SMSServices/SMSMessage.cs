using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.SMSServices
{
    public enum ProccesStatues : byte
    {
        None = 0,
        Pending = 1,
        Sending = 2,
        Sent = 3,
        SendingFailed = 4
    }

    public class SMSMessage
    {
        public ProccesStatues Status { get; internal set; }

        public DateTime? PostedDate { get; internal set; }

        public virtual string Sender { get; set; }

        public virtual string Body { get; set; }
        public virtual string Destination { get; set; }

        public SMSMessage()
        {
            Status = ProccesStatues.None;
        }
    }
}
