using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class TxReques16Bit : APIPacket_FramedID
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x01;

        #endregion

        #region Enum

        public enum CommandStatus : byte
        {
            None = 0x00,
            Disable_ACK = 0x01,
            SendWithBroadcastPanID = 0x04,
            InvokeTraceRouter = 0x08
        }

        #endregion

        #region properties

        //public byte FrameID { get; private set; }
        public byte[] DestAddress_16_Bit = new byte[2];
        public CommandStatus Options { get; private set; }
        public byte[] RF_Data { get; private set; }

        #endregion

        #region Ctor(s)

        public TxReques16Bit(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        public TxReques16Bit(byte frameID, byte[] destAddress_16_Bit, byte option, byte[] parameterValue)
        {
            API_IdentifierSpecificData = new byte[5 + (parameterValue == null ? 0 : parameterValue.Length)];
            API_IdentifierSpecificData[0] = FRAME_TYPE;
            //FrameID
            SetFrameID(frameID);

            //DestAddress_16_Bit
            DestAddress_16_Bit = destAddress_16_Bit;
            API_IdentifierSpecificData[2] = DestAddress_16_Bit[0];
            API_IdentifierSpecificData[3] = DestAddress_16_Bit[1];

            //CommandStatus
            Options = (CommandStatus)option;
            API_IdentifierSpecificData[4] = (byte)Options;

            //ParameterValue
            RF_Data = parameterValue;
            if (RF_Data != null)
            {
                Buffer.BlockCopy(RF_Data, 0, API_IdentifierSpecificData, 5, RF_Data.Length);
            }
        }

        public TxReques16Bit(byte option, byte[] parameterValue)
            : this(0, new byte[2] { 0xFF, 0xFE }, option, parameterValue)
        {

        }

        public TxReques16Bit(byte FrameID)
            : this(FrameID, new byte[2] { 0xFF, 0xFE }, 0, null)
        {

        }


        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "Tx Reques 16 Bit"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            //FrameType = data[0];
            FrameID = data[1];
            DestAddress_16_Bit[0] = data[2];
            DestAddress_16_Bit[1] = data[3];
            Options = (CommandStatus)data[4];
            if (data.Length > 5)
            {
                RF_Data = new byte[data.Length - 5];
                Buffer.BlockCopy(data, 5, RF_Data, 0, RF_Data.Length);
            }
        }

        #endregion
    }
}
