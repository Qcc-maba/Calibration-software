using System;
namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class RxPacket16Bit : APIPacket
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x81;

        #endregion

        #region properties

        public byte FrameType { get; private set; }
        public byte[] DestAddress_16_Bit = new byte[2];
        public byte RSSI { get; private set; }
        public byte Optios = 0x01;
        public byte[] RF_Data { get; private set; }

        #endregion

        #region Ctor(s)
        public RxPacket16Bit(byte[] data)
            : base(data)
        {
        }
        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return " Rx Common.Packet 16 Bit "; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            FrameType = data[0];
            DestAddress_16_Bit[0] = data[1];
            DestAddress_16_Bit[1] = data[2];
            RSSI = data[3];
            Optios = data[4];
            if (data.Length > 5)
            {
                RF_Data = new byte[data.Length - 5];
                Buffer.BlockCopy(data, 5, RF_Data, 0, RF_Data.Length);
            }
        }

        #endregion

    }
}
