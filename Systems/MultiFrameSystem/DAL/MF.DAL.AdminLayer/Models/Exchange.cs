using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class Exchange
    {
        public long UserID { get; set; }

        public long? Entry_SiteID { get; set; }
        public long? Entry_ProjectID { get; set; }
        public string Entry_SN { set; get; }
        public int DeviceCount { set; get; }
        public int RootSiteCount { set; get; }
        public int SiteTotalCount { set; get; }
        public int UpdateVersion { get; set; }
    }
}
