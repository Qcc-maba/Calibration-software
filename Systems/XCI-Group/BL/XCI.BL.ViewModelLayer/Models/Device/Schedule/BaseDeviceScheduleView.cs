using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule
{
    public class BaseDeviceScheduleView
    {
        public enum ScheduleTypes : int
        {
            Weekly = 1,
            Odd = 2,
            Even = 3
        }

        [JsonConverter(typeof(StringEnumConverter))]
        public ScheduleTypes ScheduleType { get; set; }

        public BaseDeviceScheduleView()
        {

        }




    }
}
