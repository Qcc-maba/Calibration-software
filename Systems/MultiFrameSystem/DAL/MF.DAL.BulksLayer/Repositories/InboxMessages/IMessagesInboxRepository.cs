using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages
{
    public interface IInboxMessagesRepository : IDisposable
    {
        bool AddMessage(Models.InboxMessageRecord message);
        Repositories.Models.RecordStatus[] AddMessages(IEnumerable<Models.InboxMessageRecord> messages);
        bool ReplyMessage(string OriginalMessageID, Models.InboxMessageRecord message);

        Models.InboxContentResponse GetInboxContent(string UserEmail, DateTime? from, DateTime? to, int PageSize, int PageNumber);
        Models.InboxMessageRecord GetMessage(string UserEmail, string MessageID);

        bool DeleteMessage(string UserEmail, string MessageID);
    }
}
