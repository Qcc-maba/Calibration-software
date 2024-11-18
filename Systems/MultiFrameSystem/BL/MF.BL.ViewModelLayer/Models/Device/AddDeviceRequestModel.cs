using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class AddDeviceRequestModel
    {
        public string SN { get; set; }

        public string DeviceName { get; set; }
        public MapPinLocationView Location { get; set; }
        public int ActiveZones { get; set; }
        public long? ParentSiteID { get; set; }
    }
}
