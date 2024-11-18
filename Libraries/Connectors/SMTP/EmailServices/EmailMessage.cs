using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mail;
using System.Net.Mime;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.EmailServices
{
    public enum ProccesStatues : byte
    {
        None = 0,
        Pending = 1,
        Sending = 2,
        Sent = 3,
        SendingFailed = 4
    }

    public class EmailMessage
    {
        public ProccesStatues Status { get; internal set; }
        public DateTime? PostedDate { get; internal set; }

        public virtual string From { get; set; }
        public virtual string From_DisplayName { get; set; }
        public virtual string Body { get; set; }
        public virtual string Subject { get; set; }

        public virtual string To { get; set; }
        public virtual string To_DisplayName { get; set; }

        public virtual string[] CC { get; set; }
        public virtual string[] BCC { get; set; }

        public Attachment[] Attachments { get; set; }

        public EmailMessage()
        {
            Status = ProccesStatues.None;
        }
    }
}
