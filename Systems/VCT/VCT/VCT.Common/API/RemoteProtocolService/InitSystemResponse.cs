using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class InitSystemResponse : BaseResponse
    {
        public InitSystemResponse(HardwarePacket p)
        {
            Result = p.OK;
            Message = p.ToString();
        }
        public InitSystemResponse(bool result)
            : base()
        {
            Result = result;
        }
    }
}
