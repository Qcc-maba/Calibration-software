using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class DisplaySettings
    {
        public int DisplayCharset { set; get; }
        public byte TemperatureType { get; set; }
        public byte ClockType { get; set; }
    }
}
