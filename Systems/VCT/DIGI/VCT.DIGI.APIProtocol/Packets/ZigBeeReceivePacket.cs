using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class ZigBeeReceivePacket : APIPacket
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x90;

        #endregion

        #region properties

        public byte FrameType { get; private set; }
        public byte[] DestAddress_64_Bit = new byte[8];
        public byte[] DestAddress_16_Bit = new byte[2];
        public byte ReceivedOption { get; private set; }
        public byte[] RecivedData { get; private set; }

        #endregion

        #region Ctor
        public ZigBeeReceivePacket(byte[] data)
            : base(data)
        {
        }
        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "ZigBee Receive Common.Packet"; }
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
            DestAddress_16_Bit[0] = data[9];
            DestAddress_16_Bit[1] = data[10];
            ReceivedOption = data[11];
            if (data.Length > 12)
            {
                RecivedData = new byte[data.Length - 12];
                Buffer.BlockCopy(data, 12, RecivedData, 0, RecivedData.Length);
            }
        }

        #endregion

    }
}

