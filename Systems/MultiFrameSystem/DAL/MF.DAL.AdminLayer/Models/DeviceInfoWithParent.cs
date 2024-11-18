using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class DeviceInfoWithParent : TreeNodeBase
    {
        public string SN { get; set; }
        public string DeviceName { get; set; }
        public long DeviceID { get; set; }
        public int DeviceTypeID { get; set; }
        public string DeviceTypeName { get; set; }

        /*********************** Not tested ***********************/
        public int StatusID { get; set; }
        public string StatusName { get; set; }
        public string Map_Latitude { get; set; }
        public string Map_Longitude { get; set; }
        public int? TotalActivatedZones { get; set; }
        public int MaxZones { get; set; }

        public int? TimeZoneID { get; set; }
        public string TimeSystemZoneID { get; set; }
        public string FirmwareVersion { get; set; }
        public DateTime? LastModifiedDate { get; set; }
        public DateTime? CreationDate { get; set; }
        public DateTime? HoldUntilDate { get; set; }
        public bool IsAlertsEnabled { get; set; }

    }
}
