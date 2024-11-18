using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DeviceBase
    {
        public long DeviceID { get; set; }
        public string SN { get; set; }

        public string Name { get; set; }
        public int ActivatedZones { get; set; }
        public int MaxZones { get; set; }

        public string Firmware { get; set; }

        public DateTime CreationDate { get; set; }
        public long CurrentConfigID { get; set; }
        public int ModelID { get; set; }

        public string Map_Latitude { get; set; }
        public string Map_Longitude { get; set; }


    }
}
