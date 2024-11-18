using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device
{
    public class AddDeviceRequest
    {
        public string DeviceName { get; set; }
        public long SiteID { get; set; }
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
        public int ZonesAvailable { get; set; }
        public string VerificationCode { get; set; }
        public int Type { get; set; }
        public int ModelID { get; set; }
    }
}
