using System;
using Newtonsoft.Json;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections.Generic;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Linq;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User.Messages
{
    public class InboxMessageRecordView
    {
        #region properties

        public DateTime Date { set; get; }
        public string MessageID { set; get; }

        public MessageUserInfoView TargetUserInfo { set; get; }
        public MessageUserInfoView SourceUser { set; get; }
        public BodyView.IMessageBodyView Body { set; get; }

        #endregion

        #region ctor(s)

        public InboxMessageRecordView()
        {

        }

        public InboxMessageRecordView(DAL.BulksLayer.Repositories.InboxMessages.Models.InboxMessageRecord messageRecord)
        {
            Date = messageRecord.RecordDate;
            MessageID = messageRecord.MessageID;

            TargetUserInfo = new MessageUserInfoView(messageRecord.TargetUser);
            SourceUser = new MessageUserInfoView(messageRecord.SourceUser);

            this.Body = this.ConvertFromBody(messageRecord.Body);
        }

        public InboxMessageRecordView(MessageUserInfoView tagretUser, MessageUserInfoView sourceUser, BodyView.IMessageBodyView bodyView)
        {
            this.Date = DateTime.UtcNow;
            this.TargetUserInfo = tagretUser;
            this.SourceUser = sourceUser;

            this.Body = bodyView;
        }

        #endregion

        #region private methods

        private BodyView.IMessageBodyView ConvertFromBody(string bodyObject)
        {
            if (!String.IsNullOrEmpty(bodyObject))
            {
                var token = JObject.Parse(bodyObject);

                if (token != null)
                {
                    var type = token.GetValue("TYPE") as JValue;
                    var body = token.GetValue("BODY") as JObject;

                    if (type != null)
                    {
                        switch (type.ToString())
                        {
                            case BodyView.FolderingBodyView.MESSAGE_TYPE:
                                return body.ToObject(typeof(BodyView.FolderingBodyView)) as BodyView.IMessageBodyView;
                        }
                    }
                }
            }

            return null;
        }

        public string ConvertToBody()
        {
            if (this.Body != null)
            {
                var token = new JObject(
                                       new JProperty("TYPE", this.Body.MessageType),
                                       new JProperty("BODY", JToken.FromObject(this.Body)));

                return token.ToString();
            }

            return null;
        }

        #endregion
    }
}