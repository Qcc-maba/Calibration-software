using Amazon;
using Amazon.SQS;
using Amazon.SQS.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.AWS.SQS
{
    public class BaseSQSConnector : IDisposable
    {
        private SQSSettings SQS_Setting = null;

        private AmazonSQSClient Connector;

        #region ctor

        public BaseSQSConnector(SQSSettings setting)
        {
            SQS_Setting = setting;
            Connector = new AmazonSQSClient(SQS_Setting.AwsAccessKeyId, SQS_Setting.AwsSecretAccessKey, GetRegionEndpoint(SQS_Setting.Region));
            Connector.CreateQueue(SQS_Setting.QueueName);
        }

        #endregion

        private RegionEndpoint GetRegionEndpoint(string regionName)
        {
            foreach (var item in RegionEndpoint.EnumerableAllRegions)
            {
                if (item.SystemName == regionName)
                    return item;
            }

            return RegionEndpoint.APNortheast1;
        }


        public MessageRequest InsertMessage(string Message, int? DelaySeconds = null)
        {
            //return class {Result = HttpStatusCode, id=MessageId}
            SendMessageRequest sendMessageRequest = new SendMessageRequest();
            sendMessageRequest.QueueUrl = Connector.GetQueueUrl(SQS_Setting.QueueName).QueueUrl;
            sendMessageRequest.MessageBody = Message;

            if (DelaySeconds != null)
            {
                DelaySeconds = DelaySeconds < 0 ? 0 : DelaySeconds;
                sendMessageRequest.DelaySeconds = (int)DelaySeconds;
            }
            var Request = Connector.SendMessage(sendMessageRequest);

            return new MessageRequest()
            {
                Code = Request.HttpStatusCode,
                MessageId = Request.MessageId,
                Valid = Request.HttpStatusCode == System.Net.HttpStatusCode.OK

            };
        }

        public virtual MessageRequest[] GetMessage()
        {
            var request = new ReceiveMessageRequest
            {
                MaxNumberOfMessages = SQS_Setting.ReceiveMessage.MaxNumberOfMessages,
                QueueUrl = Connector.GetQueueUrl(SQS_Setting.QueueName).QueueUrl,
                VisibilityTimeout = (int)TimeSpan.FromSeconds(SQS_Setting.ReceiveMessage.VisibilityTimeout).TotalSeconds,
                WaitTimeSeconds = SQS_Setting.ReceiveMessage.WaitTimeSeconds
            };

            var response = Connector.ReceiveMessage(request);
            return response.Messages
                .Select(m => new MessageRequest() { Body = m.Body, MessageId = m.ReceiptHandle })
                .ToArray();
        }

        public bool ReleaseMessage(string MessageId)
        {
            return Connector.DeleteMessage(new DeleteMessageRequest()
            {
                QueueUrl = Connector.GetQueueUrl(SQS_Setting.QueueName).QueueUrl,
                ReceiptHandle = MessageId
            }).HttpStatusCode == System.Net.HttpStatusCode.OK;
        }


        public bool ReleaseMessage(List<string> MessagesId)
        {
            var boolRelease = false;
            foreach (var MessageId in MessagesId)
            {
                boolRelease = Connector.DeleteMessage(new DeleteMessageRequest()
                {
                    QueueUrl = Connector.GetQueueUrl(SQS_Setting.QueueName).QueueUrl,
                    ReceiptHandle = MessageId
                }).HttpStatusCode == System.Net.HttpStatusCode.OK;
            }
            return boolRelease;
        }

        public void RemoveAllMessage()
        {
            Connector.PurgeQueue(Connector.GetQueueUrl(SQS_Setting.QueueName).QueueUrl);
        }

        public void Dispose()
        {
            Connector = null;
        }
    }
}
