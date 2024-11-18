using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.ES;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.ES.Test
{
    [TestClass]
    public class MF_DAL_BULKS__ESInboxMessagesRepositoryTests
    {
        #region ctor

        private string RandomUser = "";

        public MF_DAL_BULKS__ESInboxMessagesRepositoryTests()
        {
            RandomUser = Guid.NewGuid().ToString().Substring(0, 6);

            #region make sure we have mapping template for this repository

            var connctor = _CreateConnector();
            var settings = ((ESInboxMessagesRepository)connctor).CurrentSettings as MessagesESSettings;

            var indexTemplate = ((ESInboxMessagesRepository)connctor).GetIndexTemplate("*");

            Assert.IsNotNull(indexTemplate.TemplateMappings);

            var messagesTemplate = indexTemplate.TemplateMappings.FirstOrDefault(t => t.Value.Template.StartsWith(settings.Index_Main_Name));
            Assert.IsNotNull(messagesTemplate);
            Assert.IsNotNull(messagesTemplate.Value);

            var emailMapping = messagesTemplate.Value.Mappings.FirstOrDefault().Value.Properties.FirstOrDefault(p => p.Key.Name == "targetUserEmail");
            Assert.IsInstanceOfType(emailMapping.Value, typeof(Nest.StringProperty));
            Assert.AreEqual(((Nest.StringProperty)emailMapping.Value).Index, Nest.FieldIndexOption.NotAnalyzed, "Filed must be set as [not_analyzed]");

            #endregion
        }

        #endregion

        #region private methods

        private IInboxMessagesRepository _CreateConnector()
        {
            var settings = new MessagesESSettings()
            {
                Server_URL = @"http://localhost.fiddler:9200"
            };
            var connector = new ESInboxMessagesRepository(settings);

            return connector;
        }

        private Models.MessageUserInfo _CreateSourceUser(int? index = null)
        {
            var user = new Models.MessageUserInfo()
            {
                FirstName = $"bob{index}",
                LastName = $"Builder{index}",
                ImgURL = $"http://walla.co.il/images/bobBuilder{index}.jpeg",
                UserEmail = $"bob.buider-{index}@walla.co.il",
                UserGUID = Guid.NewGuid().ToString(),
                UserID = 9 + index.GetValueOrDefault(0)
            };

            return user;
        }

        private Models.MessageUserInfo _CreateTargetUser(int? index = null)
        {
            var user = new Models.MessageUserInfo()
            {
                FirstName = $"smai{index}{RandomUser}",
                LastName = $"fireman{index}-{RandomUser}",
                ImgURL = $"http://walla.co.il/images/samiFireman{index}.jpeg",
                UserEmail = $"sami-{index}{RandomUser}.fireman@walla.co.il",
                UserGUID = Guid.NewGuid().ToString(),
                UserID = 67 + index.GetValueOrDefault(0)
            };

            return user;
        }
        private void CompareMessages(Models.InboxMessageRecord A, Models.InboxMessageRecord B)
        {
            Assert.AreEqual(A.MessageID, B.MessageID);
            Assert.AreEqual(A.Body, B.Body);
            Assert.IsTrue((A.RecordDate - B.RecordDate).TotalSeconds <= 1);
            Assert.AreEqual(A.RecordDateT, B.RecordDateT);
            Assert.AreEqual(A.RefererMessageID, B.RefererMessageID);
            Assert.AreEqual(A.SourceUser.UserEmail, B.SourceUser.UserEmail);
            Assert.AreEqual(A.SourceUser.UserID, B.SourceUser.UserID);
            Assert.AreEqual(A.TargetUser.UserEmail, B.TargetUser.UserEmail);
            Assert.AreEqual(A.TargetUser.UserID, B.TargetUser.UserID);
        }

        #endregion

        [TestMethod()]
        public void AddMessage_Test()
        {
            var message = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                _CreateTargetUser(),
                _CreateSourceUser());

            message.Body = "Hello!!";
            message.RefererMessageID = "12345";

            using (var connector = _CreateConnector())
            {
                //add message
                var response = connector.AddMessage(message);
                Assert.IsTrue(response);

                //try get it back
                var backMessage = connector.GetMessage(message.TargetUser.UserEmail, message.MessageID);
                Assert.IsNotNull(backMessage);

                CompareMessages(backMessage, message);
            }
        }

        [TestMethod()]
        public void AddMessages_Test()
        {
            int messagesPerUser = 50;
            int usersCount = 10;

            #region creating messages

            var messages = new List<Models.InboxMessageRecord>();
            var users = new List<Models.MessageUserInfo>();
            for (int i = 0; i < usersCount; i++)
            {
                var user = _CreateTargetUser(i);
                users.Add(user);

                for (int j = 0; j < messagesPerUser; j++)
                {
                    var message = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                       user,
                       _CreateSourceUser(i));

                    messages.Add(message);
                }
            }

            #endregion

            var connector = _CreateConnector();

            var responses = connector.AddMessages(messages);
            Assert.IsNotNull(responses);
            Assert.AreEqual(responses.Length, messages.Count);
            Assert.IsTrue(responses.All(r => r.IsValid));
            Assert.IsTrue(responses.All(r => r.Version == 1));

            System.Threading.Thread.Sleep(5000);

            //get messages back
            for (int userIndex = 0; userIndex < usersCount; userIndex++)
            {
                var totalExpected = messagesPerUser;
                var pageSize = 26;

                for (int pageIndex = 0; pageIndex < 3; pageIndex++)
                {
                    var userBackMessages = connector.GetInboxContent(users[userIndex].UserEmail, null, null, pageSize, pageIndex + 1);
                    Assert.IsNotNull(userBackMessages);

                    var expectedRecords = messages
                                            .Where(m => m.TargetUser.UserEmail == users[userIndex].UserEmail)
                                            .OrderByDescending(t => t.RecordDateT)
                                            .Skip(pageIndex * pageSize)
                                            .Take(pageSize)
                                            .OrderBy(m => m.MessageID)
                                            .ToArray();

                    var backRecords = userBackMessages.Records
                                                        .OrderBy(m => m.MessageID)
                                                        .ToArray();

                    Assert.AreEqual(backRecords.Length, expectedRecords.Length);

                    for (int i = 0; i < expectedRecords.Length; i++)
                    {
                        CompareMessages(expectedRecords[i], backRecords.FirstOrDefault(r => r.MessageID == expectedRecords[i].MessageID));
                    }

                    for (int i = 0; i < expectedRecords.Length; i++)
                    {
                        CompareMessages(backRecords[i], expectedRecords.FirstOrDefault(r => r.MessageID == backRecords[i].MessageID));
                    }
                }
            }
        }

        /// <summary>
        /// Already covered by AddMessages_Test
        /// </summary>
        [TestMethod()]
        public void GetInboxContent_Test()
        {
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void ReplyMessage_Test()
        {
            //create messages
            var message = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                 _CreateTargetUser(),
                 _CreateSourceUser());

            var messageReply = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                 _CreateSourceUser(),
                 _CreateTargetUser());

            var connector = _CreateConnector();

            //add source message
            var addResult = connector.AddMessage(message);
            Assert.IsTrue(addResult);

            //add reply message
            var replyResult = connector.ReplyMessage(message.MessageID, messageReply);
            Assert.IsTrue(replyResult);

            //compare reply message
            var replyMessage_back = connector.GetMessage(messageReply.TargetUser.UserEmail, messageReply.MessageID);
            CompareMessages(messageReply, replyMessage_back);

            //compare source message
            var message_back = connector.GetMessage(message.TargetUser.UserEmail, message.MessageID);
            CompareMessages(message, message_back);
        }

        [TestMethod()]
        public void GetMessage_Test()
        {
            var message = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                 _CreateTargetUser(),
                 _CreateSourceUser());
            message.Body = "SourceMessage";

            var connector = _CreateConnector();

            //add source message
            var addResult = connector.AddMessage(message);
            Assert.IsTrue(addResult);

            //compare source message
            var message_back = connector.GetMessage(message.TargetUser.UserEmail, message.MessageID);
            CompareMessages(message, message_back);
        }

        [TestMethod()]
        public void DeleteMessage_Test()
        {
            var message = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                 _CreateTargetUser(),
                 _CreateSourceUser());

            var messageReply = InboxMessages.Models.InboxMessageRecord.CreateMessage(
                 _CreateSourceUser(),
                 _CreateTargetUser());

            var connector = _CreateConnector();

            //check message exists - before add
            var message1_back = connector.GetMessage(message.TargetUser.UserEmail, message.MessageID);
            Assert.IsNull(message1_back);

            //add source message
            var addResult = connector.AddMessage(message);
            Assert.IsTrue(addResult);

            //check message exists - after add
            var message_back = connector.GetMessage(message.TargetUser.UserEmail, message.MessageID);
            Assert.IsNotNull(message_back);
            CompareMessages(message, message_back);

            //delete message
            var message2_back = connector.DeleteMessage(message.TargetUser.UserEmail, message.MessageID);
            Assert.IsTrue(message2_back);

            //check message exists - after delete
            var message3_back = connector.GetMessage(message.TargetUser.UserEmail, message.MessageID);
            Assert.IsNull(message3_back);
        }
    }
}