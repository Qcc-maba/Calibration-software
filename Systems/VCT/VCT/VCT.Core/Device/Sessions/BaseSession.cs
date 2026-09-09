using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.VCT.Common.API;

namespace Maba.VCT.Core.Device.Sessions
{
    /// <summary>
    /// A request/response conversation with one device, serialised so only ONE request is in flight
    /// at a time.
    /// <para>
    /// Callers enqueue via QueueRequest. On each server tick <see cref="Timer"/> dequeues a single
    /// request — but only while <see cref="Avilable4Transport"/> is true, i.e. while
    /// <see cref="LastRequest"/> is null. When the reply arrives the subclass answers the caller's
    /// callback and clears LastRequest, which is what lets the next request go out.
    /// </para>
    /// <para>
    /// If a reply never arrives, SessionRequestTimeout_TimeSpan releases the session via
    /// <see cref="LastRequestTimedOut"/> (answering with a failed response). Without that, the
    /// device would keep LastRequest set forever, the queue would stop draining and the instrument
    /// would silently stop measuring — the first thing to check when a device "goes quiet".
    /// </para>
    /// </summary>
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
