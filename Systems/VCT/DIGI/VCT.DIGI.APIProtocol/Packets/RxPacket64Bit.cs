using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class RxPacket64Bit : APIPacket
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x80;

        #endregion

        #region enum

        public enum Options : byte
        {
            None = 0x00,
            Disable_ACK = 0x01,
            SendWithBroadastPANID = 0x04,
            InvokeTraceRouter = 0x08
        }

        #endregion

        #region properties

        public byte FrameType { get; private set; }
        public byte[] DestAddress_64_Bit = new byte[8];
        public byte RSSI { get; private set; }
        public byte Optios = 0x01;
        public byte[] RF_Data { get; private set; }

        #endregion

        #region Ctor(s)
        public RxPacket64Bit(byte[] data)
            : base((data))
        {
        }
        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return " Rx Common.Packet 64 Bit "; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            FrameType = data[0];
            for (int i = 1; i < 9; i++)
            {
                DestAddress_64_Bit[i - 1] = data[i];
            }
            RSSI = data[9];
            Optios = data[10];
            if (data.Length > 11)
            {
                RF_Data = new byte[data.Length - 11];
                Buffer.BlockCopy(data, 11, RF_Data, 0, RF_Data.Length);
            }
        }
        #endregion


    }
}
