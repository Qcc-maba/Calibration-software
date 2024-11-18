using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class TxReques64Bit : APIPacket_FramedID
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x00;

        #endregion

        #region enum

        public enum CommandStauses : byte
        {
            None = 0x00,
            Disable_ACK = 0x01,
            SendWithBroadastPANID = 0x04,
            InvokeTraceRouter = 0x08
        }

        #endregion

        #region properties

        public byte[] DestAddress_64_Bit = new byte[8];
        public CommandStauses Option { get; private set; }
        public byte[] RF_Data { get; private set; }

        #endregion

        #region Ctor(s)

        public TxReques64Bit(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        public TxReques64Bit(byte frameID, byte[] destAddress_64_Bit, byte option, byte[] parameterValue)
        {
            API_IdentifierSpecificData = new byte[11 + (parameterValue == null ? 0 : parameterValue.Length)];
            API_IdentifierSpecificData[0] = FRAME_TYPE;
            // FrameID
            SetFrameID(frameID);


            //DestAddress_64_Bit
            DestAddress_64_Bit = destAddress_64_Bit;
            for (int i = 2; i < 10; i++)
            {
                API_IdentifierSpecificData[i] = destAddress_64_Bit[i - 2];
            }

            //CommandStatus
            Option = (CommandStauses)option;
            API_IdentifierSpecificData[10] = (byte)Option;

            //ParameterValue
            RF_Data = parameterValue;

            if (RF_Data != null)
            {
                Buffer.BlockCopy(RF_Data, 0, API_IdentifierSpecificData, 11, RF_Data.Length);
            }
        }

        public TxReques64Bit(byte option, byte[] parameterValue)
            : this(0, new byte[8] { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, option, parameterValue)
        {

        }
        public TxReques64Bit(byte[] destAddress_64_Bit, byte[] parameterValue)
            : this(0, destAddress_64_Bit, 0, parameterValue)
        {

        }
        public TxReques64Bit(byte FrameID)
            : this(FrameID, new byte[8] { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, 0, null)
        {

        }


        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "Tx Reques 64 Bit"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            //Frame type = data[0] 
            FrameID = data[1];
            for (int i = 2; i < 10; i++)
            {
                DestAddress_64_Bit[i - 2] = data[i];
            }
            Option = (CommandStauses)data[10];
            if (data.Length > 11)
            {
                RF_Data = new byte[data.Length - 11];
                Buffer.BlockCopy(data, 11, RF_Data, 0, RF_Data.Length);
            }
        }

        #endregion
    }
}
