using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User.Messages
{
    public class InboxMessagesView
    {
        public bool Result { get; set; }
        public InboxMessageRecordView[] Messages { get; set; }
        public int TotalMessages { get; set; }
        public int PageNumber { get; set; }
        public int PageSize { get; set; }
    }
}
