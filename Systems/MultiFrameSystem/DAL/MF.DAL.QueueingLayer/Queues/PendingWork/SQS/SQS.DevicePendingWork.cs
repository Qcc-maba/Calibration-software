using Maba.Connectors.AWS.SQS;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.QueueingLayer.Queues.PendingWork.SQS
{
    public class SQSDevicePendingWork : BaseSQSConnector, IDevicePendingWork
    {
        #region ctor

        public SQSDevicePendingWork(SQSSettings setting)
            : base(setting)
        {

        }

        #endregion

        #region IDevicePendingWork members

        public void QueueOverallDeviceWork(string SN, long DeviceID, long? SiteID = null)
        {
            var message = new Models.SinglePendingWork()
            {
                Type = CONSTANTS.DEVICE_TYPE,
                SN = SN,
                SiteID = SiteID,
                DeviceID = DeviceID,
                Date = DateTime.UtcNow
            };

            this.InsertMessage(Newtonsoft.Json.JsonConvert.SerializeObject(message));
        }

        public void QueueDeviceAlertWork(string SN, long DeviceID, long AlertCode, long? SiteID = null)
        {
            var message = new Models.SinglePendingWork()
            {
                Type = CONSTANTS.ALERT_TYPE,
                SN = SN,
                Code = AlertCode,
                SiteID = SiteID,
                DeviceID = DeviceID,
                Date = DateTime.UtcNow
            };

            this.InsertMessage(Newtonsoft.Json.JsonConvert.SerializeObject(message));
        }

        public Models.SinglePendingWork[] GetMessages(long? MaxMessages, TimeSpan? Wait)
        {
            var list = base.GetMessage();

            return list.Select(m =>
                {
                    return m.Body == null ? null : Newtonsoft.Json.JsonConvert.DeserializeObject<Models.SinglePendingWork>(m.Body.ToString());
                })
                .ToArray();
        }

        #endregion
    }
}
