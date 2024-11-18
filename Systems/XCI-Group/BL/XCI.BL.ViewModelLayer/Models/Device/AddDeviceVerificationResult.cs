using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device
{
    public class AddDeviceVerificationResult
    {
        public int MaxZonesAvailable { get; set; }
        public int ZonesAvailable { get; set; }
        public string Token { get; set; }
    }
}
