using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class InitSystemResponse : DeviceBaseResponse
    {

        public InitSystemResponse()
        {

        }
        public InitSystemResponse(bool result)
            : base()
        {
            Result = result;
        }
    }
}
