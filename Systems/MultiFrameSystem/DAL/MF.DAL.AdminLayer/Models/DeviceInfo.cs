using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class DeviceInfo
    {
        public string SN { get; set; }
        public string DeviceName { get; set; }
        public long DeviceID { get; set; }
        public long? ParentSiteID { get; set; }
        public string ModelName { get; set; }
        public int ModelID { get; set; }
        public int DeviceTypeID { get; set; }
        public int DeviceTypeName { get; set; }

        public int TimeZoneID { get; set; }
        public string TimeSystemZoneID { get; set; }

    }
}
