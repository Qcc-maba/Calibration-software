using Nest;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.ES
{
    public class ESInboxMessagesRepository : Connectors.ElasticsearchLibrary.BaseElasticsearchConnector_2x, IInboxMessagesRepository
    {
        #region CONSTANTS

        public const string ELASTIC__MESSSAGES_TYPE_NAME = "UserMessages";

        //public const string ELASTIC__TEMP_INDEX_NAME = "tempdb";
        public const string ELASTIC__TYPE_DATE_FIELD = "recordDateT";
        //public const string ELASTIC__TYPE_STATUS_FIELD = "status";

        //public const string ELASTIC__ROUTING__BY_USER = "targetUser.userID";

        #endregion

        #region ctor

        public ESInboxMessagesRepository(MessagesESSettings settings)
            : base(settings)
        {
        }

        #endregion

        #region private methods

        public static string _RoutingValue(Models.InboxMessageRecord message)
        {
            return message.TargetUserEmail;
        }

        public static void _ProccessAfterGet(Models.InboxMessageRecord record)
        {
            record.RecordDate = new DateTime((record.RecordDateT * TimeSpan.TicksPerMillisecond) + Connectors.ElasticsearchLibrary.BaseElasticsearchConnector_2x.DATETIME_UNIX_1970_1JAN);
        }

        public static void _ProccessBeforePut(Models.InboxMessageRecord record)
        {
            record.RecordDateT = (record.RecordDate.Ticks - Connectors.ElasticsearchLibrary.BaseElasticsearchConnector_2x.DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond;
        }

        #endregion

        #region Implementation of IInboxMessagesRepository

        public bool AddMessage(Models.InboxMessageRecord message)
        {
            bool result = false;

            var settings = this.CurrentSettings as MessagesESSettings;

            _ProccessBeforePut(message);
            IIndexResponse respose = this.IndexRecord<Models.InboxMessageRecord>(
                                                 BuildIndexName(settings.Index_Main_Name, message.RecordDate),
                                                 ELASTIC__MESSSAGES_TYPE_NAME,
                                                 message,
                                                 null,
                                                 message.MessageID,
                                                 _RoutingValue(message));

            result = result || (respose.Created && respose.IsValid);

            return respose.Created;
        }

        public Repositories.Models.RecordStatus[] AddMessages(IEnumerable<Models.InboxMessageRecord> messages)
        {
            var settings = this.CurrentSettings as MessagesESSettings;

            foreach (var m in messages)
            {
                _ProccessBeforePut(m);
            }

            var results = this.BullkCreate<Models.InboxMessageRecord>(
                                                r => BuildIndexName(settings.Index_Main_Name, r.RecordDate),
                                                r => ELASTIC__MESSSAGES_TYPE_NAME,
                                                messages,
                                                r => r.MessageID,
                                                _RoutingValue);


            return this.Convert(results)
                .Select(r => new Repositories.Models.RecordStatus(r))
                .ToArray();
        }

        public bool ReplyMessage(string OriginalMessageID, Models.InboxMessageRecord message)
        {
            message.RefererMessageID = OriginalMessageID;
            return AddMessage(message);
        }

        public Models.InboxContentResponse GetInboxContent(string UserEmail, DateTime? from, DateTime? to, int PageSize, int PageNumber)
        {
            var now = DateTime.UtcNow;
            if (from == null)
            {
                from = now.AddMonths(-2);
            }
            if (to == null)
            {
                to = now.AddDays(1);
            }
            var settings = this.CurrentSettings as MessagesESSettings;

            var get_response = this.Search<Models.InboxMessageRecord>(
                BuildIndexName(settings.Index_Main_Name, from.Value, to.Value),
                ELASTIC__MESSSAGES_TYPE_NAME,
                //records modify
                (hit, r) =>
                {
                    _ProccessAfterGet(r);
                },
                r =>
                {
                    r.Routing = new string[] { UserEmail };
                    this.Search_Paging(r, PageSize, PageNumber);
                    this.Search_Term(r, "targetUserEmail", UserEmail);
                    this.Search_BuildRange(r, ELASTIC__TYPE_DATE_FIELD, from.Value, to.Value);
                    this.Search_SortColumns(r, ELASTIC__TYPE_DATE_FIELD + " DESC");
                });

            if (get_response.IsValid && get_response.Hits != null)
            {
                var records = get_response.Hits
                    .Select(h => h.Source)
                    .ToArray();


                return new Models.InboxContentResponse()
                {
                    Records = records
                };
            }
            else
            {
                return null;
            }
        }

        public Models.InboxMessageRecord GetMessage(string UserEmail, string MessageID)
        {
            try
            {
                var settings = this.CurrentSettings as MessagesESSettings;

                var get_response = this.GetByID<Models.InboxMessageRecord>(
                                                BuildIndexName(settings.Index_Main_Name, Models.InboxMessageRecord.ParseMessageID_Date(MessageID)),
                                                ELASTIC__MESSSAGES_TYPE_NAME,
                                                MessageID,
                                                null,
                                                null,
                                                UserEmail);

                if (get_response.IsValid && get_response != null)
                {
                    _ProccessAfterGet(get_response.Source);
                    return get_response.Source;
                }
                else
                {
                    return null;
                }
            }
            catch (Exception e)
            {
                throw e;
            }
        }

        public bool DeleteMessage(string UserEmail, string MessageID)
        {
            var settings = this.CurrentSettings as MessagesESSettings;

            var messageDate = Models.InboxMessageRecord.ParseMessageID_Date(MessageID);

            bool result = false;
            var respose = this.DeleteRecord(
                                            BuildIndexName(settings.Index_Main_Name, messageDate),
                                            ELASTIC__MESSSAGES_TYPE_NAME,
                                            MessageID,
                                            null,
                                            UserEmail);

            result = result || (respose.Found && respose.IsValid);

            return result;
        }

        #endregion
    }
}
