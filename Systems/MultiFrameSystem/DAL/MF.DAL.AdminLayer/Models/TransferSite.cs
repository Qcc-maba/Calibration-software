using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class TransferSite
    {
        public long SourceUserID { set; get; }
        public long SiteID { set; get; }
        public string TargetUserEmail { set; get; }

        public long TargetUserID { set; get; }
        public DateTime TransferDate { get; set; }
        public DateTime? RejectDate { get; set; }

        public string MessageID { set; get; }

    }
}
