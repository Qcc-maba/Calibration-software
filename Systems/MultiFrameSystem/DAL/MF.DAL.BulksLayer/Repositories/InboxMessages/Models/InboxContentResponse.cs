using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.Models
{
    public class InboxContentResponse
    {
        public IEnumerable<Models.InboxMessageRecord> Records { get; set; }
    }
}
