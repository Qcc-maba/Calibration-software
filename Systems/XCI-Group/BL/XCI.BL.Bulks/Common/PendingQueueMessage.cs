using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.Bulks.Common
{
    public class PendingQueueMessage
    {
        public DateTime MessageDate { get; set; }
        public string MessageType { get; set; }
        public long DeviceID { get; set; }
        public string SN { get; set; }
        public string Description { get; set; }
    }
}
