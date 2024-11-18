using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class DeviceAlertSettings
    {
        public long ID { get; set; }
        public int AlertCode { get; set; }
        public long DeviceID { get; set; }
        public bool IsEnable { get; set; }
        public bool IsSMSEnable { get; set; }
        public bool IsEmailEnable { get; set; }
    }   
}
