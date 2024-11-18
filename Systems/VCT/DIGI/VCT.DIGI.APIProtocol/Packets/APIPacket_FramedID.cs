
namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public abstract class APIPacket_FramedID : APIPacket
    {
        #region properties

        public byte FrameID { get; protected set; }

        #endregion

        #region ctor(s)
        
        public APIPacket_FramedID()
        {

        }
        
        public APIPacket_FramedID(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        #endregion

        #region internal methods

        internal void SetFrameID(byte id)
        {
            // FrameID
            this.FrameID = id;
            API_IdentifierSpecificData[1] = id;
        }

        #endregion
    }

}
