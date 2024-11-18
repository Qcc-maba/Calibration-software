using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.AWS.SQS
{
    public class SQSSettings
    {
        public string QueueName { get; set; }
        public string AwsAccessKeyId { get; set; }
        public string AwsSecretAccessKey { get; set; }
        public string Region { get; set; }
        public ReceiveMessageSettings ReceiveMessage { get; set; }
        public SendMessageSettings SendMessage { get; set; }

        public SQSSettings()
        {

        }
    }

    public class SendMessageSettings
    {
        public int DelaySeconds { get; set; }

        public SendMessageSettings()
        {
            DelaySeconds = 5;
        }
    }


    public class ReceiveMessageSettings
    {
        public const int MAX_VISIBILITY_TIMEOUT = 12 * 3600;
        public int MaxNumberOfMessages { get; set; }
        public int VisibilityTimeout { get; set; }
        public int WaitTimeSeconds { get; set; }

        public ReceiveMessageSettings()
        {
            MaxNumberOfMessages = 10;
            VisibilityTimeout = 10 * 60; //10 min
        }
    }
}
