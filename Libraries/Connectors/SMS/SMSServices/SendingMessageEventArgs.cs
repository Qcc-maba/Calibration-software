using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.SMSServices
{
    public class SendingMessageEventArgs : EventArgs
    {
        public SMSMessage Message { get; internal set; }
        public DateTime SentDate { get; internal set; }
        public bool Result { get; internal set; }
        public Exception Error { get; internal set; }

        public SendingMessageEventArgs(SMSMessage message, bool result, DateTime sentDate)
        {
            Message = message;

            SentDate = sentDate;
            Result = result;
        }
    }
}
