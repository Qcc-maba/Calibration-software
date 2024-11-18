
namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class GenericPacket : APIPacket
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0xFF;

        #endregion

        #region ctor

        public GenericPacket(byte[] data)
            : base(data)
        {

        }

        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "Generic"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
        }

        #endregion
    }
}
