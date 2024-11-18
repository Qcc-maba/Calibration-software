using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class UserToDevice
    {
        public long ID { get; set; }
        public bool IsEnable { get; set; }
        public long LinkID { get; set; }

        public long UserID { get; set; }
        public string UserEmail { get; set; }
        public long DeviceID { get; set; }
    }
}
