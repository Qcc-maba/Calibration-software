using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.QueueingLayer.Queues.PendingWork.Models
{
    public class SinglePendingWork
    {
        public string Type { set; get; }
        public long Code { set; get; }
        public long? SiteID { set; get; }
        public long DeviceID { set; get; }
        public string SN { set; get; }
        public DateTime Date { set; get; }
    }
}
