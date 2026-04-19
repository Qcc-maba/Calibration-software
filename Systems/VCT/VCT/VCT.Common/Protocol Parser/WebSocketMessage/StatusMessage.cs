namespace Maba.VCT.Common.Protocol_Parser.WebSocketMessage
{
    public class StatusMessage : BaseMessage
    {
        public string Value { get; set; }
        public string DeviceID { get; set; }
    }
}
