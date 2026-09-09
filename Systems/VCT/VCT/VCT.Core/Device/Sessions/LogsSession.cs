using Maba.VCT.Common.API.RemoteProtocolService;

namespace Maba.VCT.Core.Device.Sessions
{
    internal class LogsSession : BaseSession
    {
        #region ctors(s)
        public LogsSession(HardwareDeviceHost parent)
            : base(parent)
        {

        }
        #endregion

        #region overiden methods

        protected override void ProccessRequest(Common.API.BaseRequest r)
        {
            if (r.GetType() == typeof(LogsRequest))
            {
                SendPacket(r.Packet);
                if (!r.Packet.Wait4Respons)
                {
                    AnswerLastRequest(new LogsResponse(true, (r as LogsRequest).LogCommand));
                }
            }
        }

        internal override bool HandlePacket(Common.HardwarePacket p)
        {
            // Only answer when p.OK=True: the Hydra device sends "=>" (ready prompt) BEFORE "\r\n",
            // so the first packet has p.OK=False. Answering on it would give Result=False,
            // causing LogResponseCallBack to throw and preventing SCAN 1 from being queued.
            if (LastRequest != null && p.OK)
            {
                if ((LastRequest as LogsRequest).LogCommand == LogsRequest.LogCommands.LogCount)
                {
                    var res = (new LogsResponse(p.OK, (LastRequest as LogsRequest).LogCommand));
                    res.ParseLogResponse(LastRequest.Packet, p, (LastRequest as LogsRequest).LogCommand);
                    AnswerLastRequest(res);
                }
                else if ((LastRequest as LogsRequest).LogCommand == LogsRequest.LogCommands.GetLogs)
                {
                    var res = new LogsResponse(p.OK, (LastRequest as LogsRequest).LogCommand);
                    res.ParseLogResponse(LastRequest.Packet, p, (LastRequest as LogsRequest).LogCommand);
                    AnswerLastRequest(res);
                }
                else
                {
                    AnswerLastRequest(new LogsResponse(p.OK, (LastRequest as LogsRequest).LogCommand));
                }
            }
            return true;
        }

        protected override void LastRequestTimedOut()
        {
            if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.LogsRequest))
            {
                var res = new LogsResponse(false, (LastRequest as LogsRequest).LogCommand);
                res.Message = "Request was timed-out!";
                AnswerLastRequest(res);
            }
        }

        #endregion

        #region  Internals method

        internal Common.API.RemoteProtocolService.LogsResponse HandleRequest(Common.API.RemoteProtocolService.LogsRequest Request)
        {
            if (Request != null)
            {
                this.QueueRequest(Request);

                return new LogsResponse(true, (Request as LogsRequest).LogCommand);
            }
            else
            {
                return new LogsResponse(false, (Request as LogsRequest).LogCommand);
            }
        }

        #endregion

        #region Private Methods

        private void AnswerLastRequest(Common.API.RemoteProtocolService.LogsResponse response)
        {
            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                var req = LastRequest;
                LastRequest = null; // Clear BEFORE calling callback to prevent session deadlock on exception
                req.CallBackResponse(this, response);
            }
            else
            {
                LastRequest = null;
            }
        }

        #endregion
    }
}
