using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class RateResponse : DeviceBaseResponse
    {
        #region Properties


        #endregion

        #region Public methods


        public RateResponse(bool result)
        {
            Result = result;
        }

      
        #endregion
    }
}
