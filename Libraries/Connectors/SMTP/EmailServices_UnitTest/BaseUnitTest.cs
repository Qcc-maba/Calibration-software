using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Threading;

namespace Maba.Connectors.EmailServices.Tests
{
    public class BaseUnitTest
    {
        #region members

        private EmailServiceSettings _Settings = null;
        private IEmailSenderConnector _SMTPConnector = null;
        private List<SendingMessageEventArgs> SentMessages = new List<SendingMessageEventArgs>();

        #endregion

        #region settings

        public int totalMessages = 20;
        public string TargetEmailAddress = "eitanr@Maba.co.il";

        #endregion

        #region ctor

        public BaseUnitTest()
        {
            //************* GMail account example ***********************
            //_Settings = new EmailServiceSettings()
            //{
            //    EnableSsl = true,
            //    Credential_Password = "12345678",
            //    Credential_UserName = "temp@glc-service.com",
            //    Timeout = 20000,
            //    Host = "smtp.gmail.com",
            //    Port = 587,
            //    UseDefaultCredentials = false,
            //    DefaultFromAddress = "temp@glc-service.com"
            //};


            //************* SES Amazon account example ***********************
            //AWS user name  TestingOnly_AWSServices-ses-smtp-user.20161006-211106
            _Settings = new EmailServiceSettings()
            {
                EnableSsl = true,
                Credential_Password = "AodaCeQCdSoKX86yQ7tPA1/gwIH211bIbiiDMTl+zs0c",
                Credential_UserName = "AKIAJUTPAHC3YIB7Q5AA",
                Timeout = 10000,
                Host = "email-smtp.eu-west-1.amazonaws.com",
                Port = 25,
                UseDefaultCredentials = false,
                DefaultFromAddress = "mail@Maba-smart.com"
            };

            //_SMTPConnector = new Connectors.SMTPServerConnector(_Settings);
            //_SMTPConnector.SendingMessage += __SendingMessage;
        }

        #endregion

        #region private methods/events

        private void __SendingMessage(object sender, SendingMessageEventArgs e)
        {
            lock (SentMessages)
            {
                SentMessages.Add(e);
            }
        }

        #endregion

        #region protected methods

        protected void SendFewMails(string subject, Action<EmailMessage, IEmailSenderConnector> sendingMethod)
        {
            var expectedMessages = new List<EmailMessage>();
            for (int i = 0; i < totalMessages; i++)
            {
                var message = new EmailMessage()
                {
                    From = "temp@glc-service.com",
                    To = TargetEmailAddress,
                    Subject = String.Format("{0}:: Test Message {1}# from {2}",
                        subject,
                        i + 1,
                        totalMessages),
                    Body = "This is the body"
                };
                expectedMessages.Add(message);

                sendingMethod(message, _SMTPConnector);
            }

            var now = DateTime.UtcNow;

            bool done = false;
            int maxTries = 20;
            while (!done && maxTries >= 0)
            {
                Thread.Sleep(1000);
                lock (SentMessages)
                {
                    if (SentMessages.Count == expectedMessages.Count)
                    {
                        done = true;
                    }
                }
                maxTries--;
            }

            lock (SentMessages)
            {
                Assert.AreEqual(SentMessages.Count, expectedMessages.Count);

                foreach (var m in SentMessages)
                {
                    Assert.IsTrue(m.Message.Status == ProccesStatues.Sent);

                    if (!m.Result)
                        continue;

                    Assert.AreEqual(1, expectedMessages.RemoveAll(expectedMessage => m.Message.Subject == expectedMessage.Subject && m.Result));
                }
                Assert.IsTrue(!expectedMessages.Any());
            }
        }

        protected void init()
        {
            lock (SentMessages)
            {
                SentMessages.Clear();
            }
        }

        #endregion
    }
}
