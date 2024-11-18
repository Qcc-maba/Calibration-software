using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class NewTransferSiteRequest
    {
        public long SourceUserID { set; get; }
        public long SiteID { set; get; }
        public long TargetUserID { set; get; }
        public string MessageID { set; get; }
    }
}
