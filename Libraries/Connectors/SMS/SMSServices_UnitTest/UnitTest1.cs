using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Threading;

namespace Maba.Connectors.SMSServices.Test
{
    [TestClass]
    public class SMSService_NexmoConnector_UnitTest
    {
        #region static

        private static List<SendingMessageEventArgs> SentMessages = new List<SendingMessageEventArgs>();
        private static SMSServiceSettings _Settings = null;
        private static Connectors.NexmoClientConnector _NexmoConnector = null;
        private static string[] Destinations = null;
        private static string[] Messages = null;
        private static int TotalMessages = 1;

        #endregion

        #region static ctor

        static SMSService_NexmoConnector_UnitTest()
        {
            TotalMessages = 1;

            _Settings = new SMSServiceSettings()
            {
                InEnabled = true,
                DefaultSenderName = "0545429632"
            };

            _Settings.AddKey(Connectors.NexmoClientSettings.KEY__API_KEY, "2d593260");
            _Settings.AddKey(Connectors.NexmoClientSettings.KEY__API_SECRET, "b19791b1");

            _NexmoConnector = new Connectors.NexmoClientConnector(_Settings);
            _NexmoConnector.SendingMessage += _NexmoConnector_SendingMessage;

            //Rnd Team
             Destinations = new string[] { "972527406075" };
            Destinations = new string[] { "972545607831" };

            //Destinations = new string[] { "972545607831", "972547948800", "972547948836", "972527406075", "972547948816", "972547269989", "972547977589", "972545486607", "972547948803", "972502661994" };
            //Destinations = new string[] { "972527406075", "972545607831", "972523488893","972523488773" };
            //Destinations = new string[] { "972545607831"};


            //Maba Board                                 Nurit          Sagi            Zeev            Almog           Ron              Dvora            Sari
            //Destinations = new string[] { "972545607831", "972523520266", "972545429632", "972546703328", "972547948844", "972545908140", "972546488440", "972547948802"};

            Messages = new string[]{
                //"Maba Test Message 1234567890!@$%^&*()",
               // "מחקרים מראים שתינוקות ישנים על הגב נינוחים וחמודים יותר. לפרטים כנסו לאתר הכללית.",

               //"חג שמח וכשר לכל צוות ההנהלה. חירות ואושר, שמחה ובריאות. מצוות הפיתוח.",
               // "המפתחים רודים בו. הבודקים מאשימים אותו. בחג הזה כולנו יוצאים לחירות מבקרים סוררים. תודה על תקופה של מאמץ כולל. בקרוב נזכה לפרי עמלנו. חג שמח וכשר לכל צוות הפיתוח."
                //"מבצע מטורף שלא יחזור! כל החנות בחצי מחיר!"
                //"ספא במלון לאונרדו סיטי טוואר. מביאים חבר/ה חינם!"
            };
        }

        #endregion

        #region static events

        static void _NexmoConnector_SendingMessage(object sender, SendingMessageEventArgs e)
        {
            lock (SentMessages)
            {
                SentMessages.Add(e);
            }
        }

        #endregion

        [TestInitialize]
        public void Init()
        {
            lock (SentMessages)
            {
                SentMessages.Clear();
            }
        }

        [TestMethod]
        public void TestSMS_Empty()
        {
            _TestSMS("", message =>
            {
                var task = _NexmoConnector.SendAsync(message);
                Assert.IsTrue(ProccesStatues.Pending <= message.Status && message.Status <= ProccesStatues.Sent);
                Assert.IsTrue(task.Wait(_Settings.Timeout));
            });
        }

        [TestMethod]
        public void TestSMS_Async()
        {
            _TestSMS(null, message =>
            {
                var task = _NexmoConnector.SendAsync(message);
                Assert.IsTrue(ProccesStatues.Pending <= message.Status && message.Status <= ProccesStatues.Sent);
                Assert.IsTrue(task.Wait(_Settings.Timeout));
            });
        }

        [TestMethod]
        public void TestSMS_Synchronized()
        {
            _TestSMS("Synchronized", message =>
            {
                var result = _NexmoConnector.Send(message, _Settings.Timeout);
                Assert.IsTrue(message.Status == ProccesStatues.Sent);
                Assert.IsTrue(result);
            });
        }

        private void _TestSMS(string subject, Action<SMSMessage> sendingMethod)
        {
            var expectedMessages = new List<SMSMessage>();
            for (int i = 0; i < TotalMessages; i++)
            {
                foreach (var destination in Destinations)
                {
                    foreach (var body in Messages)
                    {
                        var message = new SMSMessage()
                                                            {
                                                                Body = subject + (String.IsNullOrEmpty(subject) ? "" : "::") + body,
                                                                Destination = destination
                                                            };
                        expectedMessages.Add(message);

                        sendingMethod(message);
                    }
                }
            }

            var now = DateTime.UtcNow;

            for (int i = 0; i < 20; i++)
            {
                Thread.Sleep(2000);

                lock (SentMessages)
                {
                    if (expectedMessages.Count == SentMessages.Count)
                        break;
                }
            }

            lock (SentMessages)
            {
                Assert.AreEqual(SentMessages.Count, expectedMessages.Count);

                foreach (var message in SentMessages)
                {
                    if (!message.Result)
                        continue;

                    Assert.IsTrue(expectedMessages.Any(m => m.Destination == message.Message.Destination && m.Body == message.Message.Body));
                }
            }
        }
    }
}
