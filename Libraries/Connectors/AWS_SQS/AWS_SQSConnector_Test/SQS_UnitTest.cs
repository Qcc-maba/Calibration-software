using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Linq;
namespace Maba.Connectors.AWS.SQS.Testings
{
    [TestClass]
    public class SQS_UnitTest
    {
        [TestMethod]
        public void SQS_TestMethod()
        {
            var settings = new SQSSettings()
            {
                QueueName = "HHS-SQS",
                AwsAccessKeyId = "AKIAIS2UJHGY4HV5VFPA",
                AwsSecretAccessKey = "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",
                Region = Amazon.RegionEndpoint.USWest1.SystemName,

                ReceiveMessage = new ReceiveMessageSettings(),
                SendMessage = new SendMessageSettings(),
            };

            int NumIds = 5;
            int NumPackages = 20;
            Random random = new Random();
            BaseSQSConnector SQS = new BaseSQSConnector(settings);
            SQS.RemoveAllMessage();

            for (int i = 0; i < NumPackages; i++)
            {
                int randomNumber = random.Next(0, NumIds);
                Assert.IsTrue(SQS.InsertMessage(randomNumber.ToString()).Valid);
            }

            List<MessageRequest> mList = new List<MessageRequest>();
            int tries = 0;
            while (mList.Count < NumPackages && tries < 10)
            {
                var m1 = SQS.GetMessage();
                if (m1 != null && m1.Count() > 0)
                {
                    mList.AddRange(m1.Select(m => new MessageRequest() { Body = m.Body, MessageId = m.MessageId }));
                }
                tries++;
            }

            Assert.AreEqual(mList.Count, NumPackages);

            for (int i = 0; i < NumPackages; i++)
            {
                Assert.IsTrue(SQS.ReleaseMessage(mList[i].MessageId));
            }


        }
    }
}
