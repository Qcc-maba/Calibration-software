using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public delegate void NewResponseDelegate(object sender, NewResponseEventArgs e);

    public class NewResponseEventArgs : EventArgs
    {
        #region Properties

        public BaseResponse Response { get; private set; }
        public BaseRequest NextRequest { get; set; }

        #endregion

        #region ctors(s)

        public NewResponseEventArgs(BaseResponse r)
        {
            this.Response = r;
        }

        #endregion
    }
}
