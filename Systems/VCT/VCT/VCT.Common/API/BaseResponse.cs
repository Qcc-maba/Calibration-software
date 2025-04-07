using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API
{
    public class BaseResponse
    {
        #region Members

        public bool HasResponse { get; set; }

        public string Message { get; set; }

        public bool Result { get; set; }

        public bool Expired { get; set; }

        public string SN { get; set; }
        #endregion

        #region ctors(s)

        public BaseResponse()
            : base()
        {
        }
        public BaseResponse(bool result)
           : base()
        {
            Result = result;
        }
        #endregion
    }
}
