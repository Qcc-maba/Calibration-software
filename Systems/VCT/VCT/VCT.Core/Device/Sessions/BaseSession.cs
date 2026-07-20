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

        public HardwareDeviceHost Parent { get; private set; }

        public virtual bool Avilable4Transport
        {
            get { return LastRequest == null; }
        }

        protected Common.API.BaseRequest LastRequest { get; set; }

        #endregion

        #region Members

        private ConcurrentQueue<Common.API.BaseRequest> QueuedRequests = new ConcurrentQueue<Common.API.BaseRequest>();

        /// <summary>
        /// When the current <see cref="LastRequest"/> was actually sent. Deliberately not
        /// <c>BaseRequest.CreationDate</c>, which is the enqueue time — a request that waited in a
        /// backed-up queue would otherwise be considered timed-out the moment it is sent.
        /// </summary>
        private DateTime _lastRequestSentUtc;

        #endregion

        #region Ctor(s)

        public BaseSession(HardwareDeviceHost parent)
        {
            Parent = parent;
        }

        #endregion

        #region internal methods

        internal virtual void Timer()
        {
            if (Avilable4Transport && QueuedRequests.Count > 0)
            {
                Common.API.BaseRequest r = null;
                if (QueuedRequests.TryDequeue(out r))
                {
                    LastRequest = r;
                    _lastRequestSentUtc = DateTime.UtcNow;
                    ProccessRequest(LastRequest);
                }
            }

            // Without this, a device that never answers (unplugged mid-scan, garbled frame) leaves
            // LastRequest set forever: Avilable4Transport stays false, the queue stops draining and
            // this session silently stops measuring until the server restarts.
            if (LastRequest != null && Parent != null && Parent.DeviceSettings != null)
            {
                var timeout = Parent.DeviceSettings.SessionRequestTimeout_TimeSpan;
                if (timeout > TimeSpan.Zero && DateTime.UtcNow - _lastRequestSentUtc > timeout)
                {
                    Libs.Trace.Tracer.Info("[Session] {0} request timed out after {1}s - releasing session for {2}.",
                        this.GetType().Name, timeout.TotalSeconds, Parent.SN);
                    LastRequestTimedOut();
                }
            }
        }

        internal virtual void Start()
        {

        }

        internal virtual bool HandlePacket(Common.HardwarePacket p)
        {
            return true;
        }

        #endregion

        #region protected/abstract methods

        protected void SendPacket(Common.HardwarePacket p)
        {
            Parent.SendPacket(p);
        }

        internal void OnDisconnect()
        {
            this.LastRequest = null;

            Common.API.BaseRequest r = null;

            //empty all queued sessions
            while (this.QueuedRequests.TryDequeue(out r))
            {

            }
        }

        protected virtual void OnConnection()
        {

        }

        protected abstract void ProccessRequest(Common.API.BaseRequest r);

        protected abstract void LastRequestTimedOut();

        protected void QueueRequest(Common.API.BaseRequest r)
        {
            //Libs.Trace.Tracer.Info($"BaseSession : New Request : {r.GetType().Name}");

            r.CreationDate = DateTime.UtcNow;
            QueuedRequests.Enqueue(r);
        }

        #endregion
    }
}
