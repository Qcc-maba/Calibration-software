using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class TransferSiteView
    {
        public string TargetUserEmail { set; get; }
        public long SiteID { set; get; }
        public DateTime TransferDate { get; set; }
        public DateTime? RejectDate { get; set; }

        public TransferSiteView()
        {

        }

        public TransferSiteView(DAL.AdminLayer.Models.TransferSite TransferSite)
        {
            TargetUserEmail = TransferSite.TargetUserEmail;
            SiteID = TransferSite.SiteID;
            TransferDate = TransferSite.TransferDate;
            RejectDate = TransferSite.RejectDate;
        }
    }
}
