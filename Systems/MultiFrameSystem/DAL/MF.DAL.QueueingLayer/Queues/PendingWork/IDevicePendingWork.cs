using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.QueueingLayer.Queues.PendingWork
{
    public interface IDevicePendingWork : IDisposable
    {
        void QueueOverallDeviceWork(string SN, long DeviceID, long? SiteID = null);
        void QueueDeviceAlertWork(string SN, long DeviceID, long AlertCode, long? SiteID = null);

        Models.SinglePendingWork[] GetMessages(long? MaxMessages, TimeSpan? Wait);
    }
}
