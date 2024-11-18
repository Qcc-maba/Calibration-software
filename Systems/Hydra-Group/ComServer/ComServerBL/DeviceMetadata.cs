using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.BL.Hydra2Devices
{
    public class DeviceMetadata
    {
        public int MaxZones { get; set; }
        public long DeviceID { get; set; }
        public long ParentID { get; set; }
        public TimeSpan TimeOffset { get; set; }
        //public Settings.HydraBL_DeviceType DeviceType { get; set; }
        public DeviceMetadata()
        {
        }
    }
}
