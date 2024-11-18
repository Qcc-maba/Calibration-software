using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device.Sessions
{
    internal class LogsSession : BaseSession
    {
        #region ctors(s)
        public LogsSession(DeviceHost parent)
            : base(parent)
        {

        }
        #endregion

        #region overiden methods

        protected override void ProccessRequest(Common.API.DeviceBaseRequest r)
        {
            if (r.GetType() == typeof(Common.API.RemoteProtocolService.LogsRequest))
            {
                SendPacket(r.Packet);
                if (!r.Packet.Wait4Respons)
                {
                    AnswerLastRequest(new LogsResponse(true));
                }
            }
        }

        internal override bool HandlePacket(Common.Packet p)
        {
            if (LastRequest != null)
            {
                if ((LastRequest as LogsRequest).LogCommand == LogsRequest.LogCommands.LogCount)
                {
                    string numOfLogs = p.Response.Replace("\r\n", "").Replace("=>", "");
                    int numOfLogsLength = int.Parse(numOfLogs);
                    AnswerLastRequest(new LogsResponse(p.OK, (LastRequest as LogsRequest).LogCommand, numOfLogsLength));
                }
                else if ((LastRequest as LogsRequest).LogCommand == LogsRequest.LogCommands.GetLogs)
                {
                    var res = new LogsResponse(p, (LastRequest as LogsRequest).LogCommand, !LastRequest.Packet.Command.Contains("DATA"));
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
                AnswerLastRequest(new Common.API.RemoteProtocolService.LogsResponse(false)
                {
                    Message = "Request was timed-out!"
                });
            }
        }

        #endregion

        #region  Internals method

        internal Common.API.RemoteProtocolService.LogsResponse HandleRequest(Common.API.RemoteProtocolService.LogsRequest Request)
        {
            if (Request != null)
            {
                this.QueueRequest(Request);

                return new Common.API.RemoteProtocolService.LogsResponse(true);
            }
            else
            {
                return new Common.API.RemoteProtocolService.LogsResponse(false);
            }
        }

        #endregion

        #region Private Methods

        private void AnswerLastRequest(Common.API.RemoteProtocolService.LogsResponse response)
        {
            if (LastRequest != null && LastRequest.CallBackResponse != null)
            {
                LastRequest.CallBackResponse(this, response);
            }
            LastRequest = null;
        }

        #endregion
    }
}
