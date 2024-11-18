using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DeviceSettings
    {
        public bool UserWeatherSavingAlgorithm { get; set; }

        public DateTime? HoldUntil { get; set; }

        public bool UseSiteSessionSettings { get; set; }


        public int? HoldType { get; set; }
    }
}
