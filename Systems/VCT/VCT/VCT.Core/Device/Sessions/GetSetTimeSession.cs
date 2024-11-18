using Maba.VCT.Common;
using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;
using System;
using System.Text;

namespace Maba.VCT.Core.Device.Sessions
{
    internal class GetSetTimeSession : BaseSession
    {
        #region Ctor(s)

        public GetSetTimeSession(DeviceHost parent)
            : base(parent)
        {
        }

        #endregion

        #region Private methods

        private void AnswerLastRequest(BaseResponse response)
        {
            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                //response.SN = this.Parent.SN;
                LastRequest.CallBackResponse(this, response);
            }
            LastRequest = null;
        }

        private void AnswerLastRequest(Common.API.RemoteProtocolService.GetSetDateResponse response)
        {
            response.SN = this.Parent.SN;
            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                LastRequest.CallBackResponse(this, response);
            }
            LastRequest = null;
        }

        #endregion

        #region Internal methods

        internal Common.API.RemoteProtocolService.GetSetDateResponse HandleRequest(Common.API.RemoteProtocolService.GetSetDateRequest Request)
        {
            this.QueueRequest(Request);
            return new Common.API.RemoteProtocolService.GetSetDateResponse(true);
        }

        #endregion

        #region Overridden from BaseSession

        internal override bool HandlePacket(Common.Packet p)
        {
            if (LastRequest != null && LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.GetSetDateRequest))
            {
                AnswerLastRequest(new GetSetDateResponse(p.OK));
                return true;
            }
            return false;
        }
        protected override void ProccessRequest(Common.API.DeviceBaseRequest r)
        {
            if (r != null && r.Packet != null)
            {
                SendPacket(r.Packet);
                if (!r.Packet.Wait4Respons)
                {
                    AnswerLastRequest(new GetSetDateResponse(true));
                }
            }
        }
        protected override void LastRequestTimedOut()
        {
            if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.GetSetDateRequest))
            {
                AnswerLastRequest(new Common.API.RemoteProtocolService.GetSetDateResponse(false)
                {
                    Message = "Request was timed-out!",
                });
            }
            else if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.GetSetDateRequest))
            {
                AnswerLastRequest(new Common.API.RemoteProtocolService.GetSetDateResponse(false)
                {
                    Message = "Request was timed-out!"
                });
            }
            else if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.GetSetDateRequest))
            {
                AnswerLastRequest(new Common.API.RemoteProtocolService.GetSetDateResponse(false)
                {
                    Message = "Request was timed-out!"
                });
            }

        }

        #endregion
    }
}
