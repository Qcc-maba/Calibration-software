using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class AddDeviceResponseModel
    {
        public string SN { get; set; }
        public bool Status { get; set; }

        public long? ParentSiteID { get; set; }

        public bool SelfOwned { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public StatusReasons StatusReason { get; set; }
        public Models.Device.DeviceTypeView SystemDeviceType { get; set; }
        public int MaxZones { get; set; }
    }
}
