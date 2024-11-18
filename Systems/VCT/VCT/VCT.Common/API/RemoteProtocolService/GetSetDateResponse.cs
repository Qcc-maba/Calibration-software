using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class GetSetDateResponse : DeviceBaseResponse
    {
    

        #region ctors(s)

        public GetSetDateResponse(bool result)
            : base()
        {
            Result = result;
        }

        public Packet ResponsePacket { get; set; }

        #endregion
    }
}
