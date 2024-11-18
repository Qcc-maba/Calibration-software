using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.EmailServices
{
    public delegate void SendingMessageDelegate(object sender, SendingMessageEventArgs e);

    public interface IEmailSenderConnector : IDisposable
    {
        event SendingMessageDelegate SendingMessage;

        bool Send(EmailMessage message, int timeoutMilliseconds = 60000);
        Task<bool> SendAsync(EmailMessage message);
    }
}
