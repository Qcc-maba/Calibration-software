using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.AWS.SQS;

namespace Maba.Connectors.QueueLibrary.AWS_SQS
{
    public class SQSQueueConnector : BaseSQSConnector, IQueueConnector
    {
        #region ctor

        public SQSQueueConnector(SQSSettings setting)
            : base(setting)
        {

        }

        #endregion

        #region IQueueConnector members

        public void Queue<T>(T Message) where T : class
        {
            var data_str = Newtonsoft.Json.JsonConvert.SerializeObject(Message);
            this.InsertMessage(data_str);
        }
        public void Queue(string Message)
        {
            this.InsertMessage(Message);
        }

        public QMessage<T>[] GetMessages<T>(long? MaxMessages, TimeSpan? Wait)
        {
            var list = base.GetMessage();

            return list
                .Select(m =>
                {
                    return m.Body == null ? null : new QMessage<T>()
                    {
                        Content = Newtonsoft.Json.JsonConvert.DeserializeObject<T>(m.Body.ToString()),
                        ID = m.MessageId
                    };
                })
                .ToArray();
        }

        #endregion
    }
}
