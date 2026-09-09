using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.VCT.Core.Device.Sessions
{
    class InitChannelsSession : BaseSession
    {

        #region Ctor
        public InitChannelsSession(HardwareDeviceHost parent)
            : base(parent)
        {

        }

        #endregion

        #region Overridden Methods

        internal override bool HandlePacket(Common.HardwarePacket p)
        {
            // Only answer when p.OK=True: Hydra sends "=>" first (p.OK=False), then "\r\n" (p.OK=True)
            if (LastRequest != null && p.OK && LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.InitChannelsRequest))
            {
                AnswerLastRequest(new InitChannelsResponse(p.OK));
                return true;
            }
            return false;
        }

        private void AnswerLastRequest(BaseResponse response)
        {
            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                var req = LastRequest;
                LastRequest = null;
                req.CallBackResponse(this, response);
            }
            else
            {
                LastRequest = null;
            }
        }
        internal Common.API.RemoteProtocolService.InitChannelsResponse HandleRequest(Common.API.RemoteProtocolService.InitChannelsRequest Request)
        {
            this.QueueRequest(Request);
            return new Common.API.RemoteProtocolService.InitChannelsResponse(true);
        }

        protected override void ProccessRequest(Common.API.BaseRequest r)
        {
            if (r.GetType() == typeof(Common.API.RemoteProtocolService.InitChannelsRequest))
            {
                SendPacket(r.Packet);
                if (!r.Packet.Wait4Respons)
                {
                    AnswerLastRequest(new InitChannelsResponse(true));
                }
            }
        }

        protected override void LastRequestTimedOut()
        {
            if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.InitChannelsRequest))
            {
                AnswerLastRequest(new Common.API.RemoteProtocolService.InitChannelsResponse(false)
                {
                    Message = "Request was timed-out!",
                });
            }
        }

        #endregion
    }
}
