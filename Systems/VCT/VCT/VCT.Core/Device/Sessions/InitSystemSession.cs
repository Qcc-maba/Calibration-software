using Maba.VCT.Common;
using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Device.Sessions;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device.Sessions
{
    internal class InitSystemSession : BaseSession
    {

        #region Ctor(s)

        public InitSystemSession(HardwareDeviceHost parent)
            : base(parent)
        {
        }

        #endregion

        protected override void LastRequestTimedOut()
        {
            if (LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.InitSystemRequest))
            {
                AnswerLastRequest(new Common.API.RemoteProtocolService.InitSystemResponse(false)
                {
                    Message = "Request was timed-out!",
                });
            }
        }
        private void AnswerLastRequest(BaseResponse response)
        {
            response.SN = this.Parent.SN;

            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                LastRequest.CallBackResponse(this, response);
            }
            LastRequest = null;
        }

        protected override void ProccessRequest(BaseRequest r)
        {
            if (r != null & r.Packet != null)
            {
                SendPacket(r.Packet);
                if (!r.Packet.Wait4Respons)
                {
                    AnswerLastRequest(new InitSystemResponse(true));
                }
            }
        }
        internal override bool HandlePacket(Common.HardwarePacket p)
        {
            if (LastRequest != null && LastRequest.GetType() == typeof(Common.API.RemoteProtocolService.InitSystemRequest))
            {
                AnswerLastRequest(new InitSystemResponse(p));
                return true;
            }
            return false;
        }

        public InitSystemResponse HandleRequest(InitSystemRequest request)
        {
            if (request != null)
            {
                this.QueueRequest(request);

                return new Common.API.RemoteProtocolService.InitSystemResponse(true);
            }
            else
            {
                return new Common.API.RemoteProtocolService.InitSystemResponse(false);
            }
        }
    }
}
