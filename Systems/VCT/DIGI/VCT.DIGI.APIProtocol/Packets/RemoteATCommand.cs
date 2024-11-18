using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class RemoteATCommand : APIPacket_FramedID
    {
        #region CONSTANT
        public const byte FRAME_TYPE = 0x17;
        #endregion

        #region enum

        public enum RemoteCommand : byte
        {
            None = 0x00,
            Disable_ACK = 0x01,
            ApplyChanges = 0x02,
            ExtenfdedTimeout = 0x40
        }

        #endregion

        #region properties
        public string AT_Command { get; private set; }
        public byte[] DestAddress_64_Bit = new byte[8];
        public byte[] DestAddress_16_Bit = new byte[2];
        public RemoteCommand CommandStatus { get; private set; }
        public byte[] ParameterValue { get; private set; }

        #endregion

        #region Ctor

        public RemoteATCommand(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        public RemoteATCommand(byte frameID, byte[] destAddress_64_Bit, byte[] destAddress_16_Bit, byte commandStatus, string aT_Command, byte[] parameterValue)
        {
            API_IdentifierSpecificData = new byte[15 + (parameterValue == null ? 0 : parameterValue.Length)];
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

            //CommandStatus
            CommandStatus = (RemoteCommand)commandStatus;
            API_IdentifierSpecificData[12] = commandStatus;

            //AT_Command
            AT_Command = aT_Command;
            API_IdentifierSpecificData[13] = (byte)aT_Command[0];
            API_IdentifierSpecificData[14] = (byte)aT_Command[1];

            //ParameterValue
            ParameterValue = parameterValue;

            if (parameterValue != null)
            {
                Buffer.BlockCopy(parameterValue, 0, API_IdentifierSpecificData, 15, parameterValue.Length);
            }

        }

        public RemoteATCommand(string aTCommand, byte[] parameterValue)
            : this(0, new byte[8] { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, new byte[2] { 0xFF, 0xFE }, (byte)RemoteCommand.None, aTCommand, parameterValue)
        {

        }

        public RemoteATCommand(byte FrameID, string ATCommand)
            : this(FrameID, new byte[8] { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF }, new byte[2] { 0xFF, 0xFE }, (byte)RemoteCommand.None, ATCommand, null)
        {

        }

        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "Remote AT Command"; }
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
            CommandStatus = (RemoteCommand)data[12];
            AT_Command = string.Concat((char)data[13], (char)data[14]);
            if (data.Length > 15)
            {
                ParameterValue = new byte[data.Length - 15];
                Buffer.BlockCopy(data, 15, ParameterValue, 0, ParameterValue.Length);
            }
        }
        #endregion

    }
}
