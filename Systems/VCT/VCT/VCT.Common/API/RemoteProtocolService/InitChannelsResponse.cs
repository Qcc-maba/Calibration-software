using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class InitChannelsResponse : DeviceBaseResponse
    {

        #region Ctor

        public InitChannelsResponse(bool result)
        {
            Result = result;
        }

        #endregion
    }
}
