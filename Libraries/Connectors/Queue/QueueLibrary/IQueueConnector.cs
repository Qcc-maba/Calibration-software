using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.QueueLibrary
{
    public interface IQueueConnector : IDisposable
    {
        void Queue<T>(T Message) where T : class;

        void Queue(string Message);

        QMessage<T>[] GetMessages<T>(long? MaxMessages, TimeSpan? Wait);
    }
}
