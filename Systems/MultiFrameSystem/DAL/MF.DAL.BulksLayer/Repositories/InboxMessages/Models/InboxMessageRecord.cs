using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.Models
{
    public class InboxMessageRecord
    {
        #region CONSTANTS

        private const string MESSAGE_ID__DATE_FORMAT = "yyMMddHHmmss";

        #endregion

        #region properties
        public string RefererMessageID { get; set; }
        public string TargetUserEmail { get; set; }

        public string MessageID { get; set; }

        public DateTime RecordDate { get; set; }

        public long RecordDateT { get; set; }

        public MessageUserInfo TargetUser { get; set; }
        public MessageUserInfo SourceUser { get; set; }

        public string Body { get; set; }

        #endregion

        #region ctor

        public InboxMessageRecord()
        {

        }


        #endregion

        #region public static methods

        public static InboxMessageRecord CreateMessage(MessageUserInfo targetUser, MessageUserInfo sourceUser = null, string body = null)
        {
            var now = DateTime.UtcNow;

            var message = new InboxMessageRecord()
            {
                TargetUserEmail = targetUser.UserEmail,
                TargetUser = targetUser,
                SourceUser = sourceUser,
                MessageID = $"{now.ToString(MESSAGE_ID__DATE_FORMAT)}-{Guid.NewGuid().ToString().Substring(0, 5)}-{targetUser.UserEmail}",
                RecordDate = now,
                Body = body
            };

            return message;
        }

        #endregion

        #region internal static
        internal static DateTime ParseMessageID_Date(string MessageID)
        {
            return DateTime.ParseExact(MessageID.Split('-')[0], MESSAGE_ID__DATE_FORMAT, CultureInfo.InvariantCulture, DateTimeStyles.None);
        }

        #endregion

    }
}
