using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Remoting.Messaging;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class InitChannelsRequest : BaseRequest
    {
        #region Members

        private int ChannelNumber;

        #endregion
        #region Ctor(s)
        public InitChannelsRequest()
            : base()
        {

        }

        public InitChannelsRequest(int channelNum) : this()
        {
            this.ChannelNumber = channelNum;
        }

        #endregion
    }
}
