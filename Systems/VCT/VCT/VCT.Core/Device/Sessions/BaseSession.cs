using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.VCT.Common.API;

namespace Maba.VCT.Core.Device.Sessions
{
    internal abstract class BaseSession
    {
        #region Peopeties

        public DeviceHost Parent { get; private set; }

        public virtual bool Avilable4Transport
        {
            get { return LastRequest == null; }
        }

        protected Common.API.DeviceBaseRequest LastRequest { get; set; }

        #endregion

        #region Members

        private ConcurrentQueue<Common.API.DeviceBaseRequest> QueuedRequests = new ConcurrentQueue<Common.API.DeviceBaseRequest>();

        #endregion

        #region Ctor(s)

        public BaseSession(DeviceHost parent)
        {
            Parent = parent;
        }

        #endregion

        #region internal methods

        internal virtual void Timer()
        {
            if (Avilable4Transport && QueuedRequests.Count > 0)
            {
                Common.API.DeviceBaseRequest r = null;
                if (QueuedRequests.TryDequeue(out r))
                {
                    LastRequest = r;
                    ProccessRequest(LastRequest);
                }
            }

            //if (LastRequest != null && DateTime.UtcNow - LastRequest.CreationDate > Parent.DeviceSettings.SessionRequestTimeout_TimeSpan)
            //{
            //    LastRequestTimedOut();
            //}
        }

        internal virtual void Start()
        {

        }

        internal virtual bool HandlePacket(Common.Packet p)
        {
            return true;
        }

        #endregion

        #region protected/abstract methods

        protected void SendPacket(Common.Packet p)
        {
            Parent.SendPacket(p);
        }

        internal void OnDisconnect()
        {
            this.LastRequest = null;

            Common.API.DeviceBaseRequest r = null;

            //empty all queued sessions
            while (this.QueuedRequests.TryDequeue(out r))
            {

            }
        }

        protected virtual void OnConnection()
        {

        }

        protected abstract void ProccessRequest(Common.API.DeviceBaseRequest r);

        protected abstract void LastRequestTimedOut();

        protected void QueueRequest(Common.API.DeviceBaseRequest r)
        {
            //Libs.Trace.Tracer.Info($"BaseSession : New Request : {r.GetType().Name}");

            r.CreationDate = DateTime.UtcNow;
            QueuedRequests.Enqueue(r);
        }

        #endregion
    }
}
