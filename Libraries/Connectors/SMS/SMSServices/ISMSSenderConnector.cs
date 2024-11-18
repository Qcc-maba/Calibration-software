using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.SMSServices
{
    public delegate void SendingMessageDelegate(object sender, SendingMessageEventArgs e);

    public interface ISMSSenderConnector
    {
        event SendingMessageDelegate SendingMessage;
        Task<bool> SendAsync(SMSMessage message);
        bool Send(SMSMessage message, int timeoutMilliseconds);
    }
}
