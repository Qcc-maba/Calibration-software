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
            Message = p.ToString();
        }
        public InitSystemResponse(bool result)
            : base()
        {
            Result = result;
        }
    }
}
