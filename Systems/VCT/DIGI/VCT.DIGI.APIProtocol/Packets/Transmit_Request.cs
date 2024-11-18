using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class Transmit_Request : APIPacket_FramedID
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x10;

        #endregion

        #region properties

        //public byte FrameID { get; private set; }
        public byte[] DestAddress_64_Bit = new byte[8];
        public byte[] DestAddress_16_Bit = new byte[2];
        public byte BroadcastRadius { get; private set; }
        public byte Options { get; private set; }
        public byte[] RF_Data { get; private set; }

        #endregion

        #region Ctor
        public Transmit_Request(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        public Transmit_Request(byte frameID, byte[] destAddress_64_Bit, byte[] destAddress_16_Bit, byte broadcastRadius, byte options, byte[] parameterValue)
        {
            API_IdentifierSpecificData = new byte[14 + (parameterValue == null ? 0 : parameterValue.Length)];
            API_IdentifierSpecificData[0] = FRAME_TYPE;
            //FrameID
            SetFrameID(frameID);

            //DestAddress_64_Bit
            DestAddress_64_Bit = destAddress_64_Bit;
            for (int i = 2; i < 10; i++)
            {
                API_IdentifierSpecificData[i] = destAddress_64_Bit[i - 2];
            }

            //DestAddress_16_Bit
            DestAddress_16_Bit = destAddress_16_Bit;
            API_IdentifierSpecificData[10] = destAddress_16_Bit[0];
            API_IdentifierSpecificData[11] = destAddress_16_Bit[1];

            //BroadcastRadius
            BroadcastRadius = broadcastRadius;
            API_IdentifierSpecificData[12] = BroadcastRadius;

            //Options
            Options = options;
            API_IdentifierSpecificData[13] = options;

            //ParameterValue
            RF_Data = parameterValue;

            if (RF_Data != null)
            {
                Buffer.BlockCopy(RF_Data, 0, API_IdentifierSpecificData, 14, RF_Data.Length);
            }

        }

        public Transmit_Request(byte[] Address64Bit, byte[] parameterValue)
            : this(0, Address64Bit, new byte[2] { 0xFF, 0xFE }, 0, 0, parameterValue)
        {

        }
        public Transmit_Request(byte[] Address64Bit, byte[] destAddress_16_Bit, byte[] parameterValue)
            : this(0, Address64Bit, destAddress_16_Bit, 0, 0, parameterValue)
        {

        }
        public Transmit_Request()
            : this(0, new byte[8] { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, new byte[2] { 0xFF, 0xFE }, 0, 0, null)
        {

        }
        public Transmit_Request(byte broadcast, byte[] data)
            : this(0, new byte[8] { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, new byte[2] { 0xFF, 0xFE }, broadcast, 0, data)
        {

        }
        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "Transmit Request"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            //FrameType = data[0];
            FrameID = data[1];
            for (int i = 2; i < 10; i++)
            {
                DestAddress_64_Bit[i - 2] = data[i];
            }
            DestAddress_16_Bit[0] = data[10];
            DestAddress_16_Bit[1] = data[11];
            BroadcastRadius = data[12];
            Options = data[13];
            if (data.Length > 14)
            {
                RF_Data = new byte[data.Length - 14];
                Buffer.BlockCopy(data, 14, RF_Data, 0, RF_Data.Length);
            }
        }

        #endregion
    }
}
