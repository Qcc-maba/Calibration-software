using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using System.Web;

namespace Maba.VCT.Common
{
    public class WebSocketPacket : IPacket
    {
        #region Members
        [JsonPropertyName("CMD")]
        public string Command { get; set; }

        [JsonPropertyName("LoggerID")]
        public string LoggerId { get; set; }

        [JsonPropertyName("IP")]
        public string IpAddress { get; set; }

        [JsonPropertyName("Rate")]
        public string Rate { get; set; }

        [JsonPropertyName("Interval")]
        public string Interval { get; set; }

        [JsonPropertyName("BatchID")]
        public string BatchId { get; set; }

        [JsonPropertyName("BatchChannels")]
        public string BatchChannels { get; set; }

        public string RawData { get; private set; }
        #endregion

        #region Ctor

        public WebSocketPacket(string data)
        {
            RawData = data;

        }

        #endregion

        #region Override from IPacket
        public override string ToString()
        {
            return base.ToString();
        }

        #endregion


    }

}
