using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API
{
    public delegate void CallbackResponseDelegate(object sender, BaseResponse response);

    public class BaseRequest
    {
        #region Members

        public DateTime CreationDate { get; set; }

        public DateTime LastRequestHandling { get; set; }

        public CallbackResponseDelegate CallBackResponse { get; set; }

        public bool ExpectedResponse { get; set; }

        public HardwarePacket Packet { get; set; }
        /// <summary>
        /// Time-To-Live in Seconds
        /// </summary>
        public int TTL { get; set; }

        #endregion

        #region ctors(s)

        public BaseRequest()
        {
            CreationDate = LastRequestHandling = DateTime.UtcNow;
        }

        #endregion

    }
}
