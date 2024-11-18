using Maba.VCT.Common;
using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;
using System;

namespace Maba.VCT.Core.Device.Sessions
{
    internal class RateSession : BaseSession
    {
        public RateSession(DeviceHost parent) : base(parent)
        {
        }

        protected override void LastRequestTimedOut()
        {
            if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.RateRequest))
            {
                AnswerLastRequest(new Common.API.RemoteProtocolService.RateResponse(false)
                {
                    Message = "Request was timed-out!",
                });
            }
        }

        protected override void ProccessRequest(Common.API.DeviceBaseRequest r)
        {
            if (r.GetType() == typeof(Common.API.RemoteProtocolService.RateRequest))
            {
                SendPacket(r.Packet);
                if (!r.Packet.Wait4Respons)
                {
                    AnswerLastRequest(new RateResponse(true));
                }
            }
        }

        internal Common.API.RemoteProtocolService.RateResponse HandleRequest(Common.API.RemoteProtocolService.RateRequest Request)
        {
            this.QueueRequest(Request);
            return new Common.API.RemoteProtocolService.RateResponse(true);
        }

        private void AnswerLastRequest(BaseResponse response)
        {
            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                //response.SN = this.Parent.SN;
                LastRequest.CallBackResponse(this, response);
            }
            LastRequest = null;
        }
        internal override bool HandlePacket(Common.Packet p)
        {
            if (LastRequest != null && LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.RateRequest))
            {
                AnswerLastRequest(new RateResponse(p.OK));
                return true;
            }
            return false;
        }
    }
}