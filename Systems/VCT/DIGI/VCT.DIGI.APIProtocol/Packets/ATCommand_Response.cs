using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class ATCommand_Response : APIPacket_FramedID
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x88;

        #endregion

        #region properties

        public string AT_Command { get; private set; }
        public byte[] ParameterValue { get; private set; }
        public CommandStatus CommandStatusOption { get; private set; }

        #endregion

        #region Enum
        public enum CommandStatus : byte
        {
            OK = 0x00,
            Error = 0x01,
            InvalidCommand = 0x02,
            InvalidParameter = 0x03,
            TxFailure = 0x04
        }
        #endregion

        #region Ctor

        internal ATCommand_Response(byte[] data)
            : base(data)
        {
        }

        public ATCommand_Response(byte frameID, string aTCommand, CommandStatus status, byte[] parameterValue)
        {
            API_IdentifierSpecificData = new byte[5 + (parameterValue == null ? 0 : parameterValue.Length)];

            API_IdentifierSpecificData[0] = FRAME_TYPE;

            // FrameID
            SetFrameID(frameID);

            //ATCommand
            AT_Command = aTCommand;
            API_IdentifierSpecificData[2] = (byte)aTCommand[0];
            API_IdentifierSpecificData[3] = (byte)aTCommand[1];

            //status
            API_IdentifierSpecificData[4] = (byte)status;

            //ParameterValue
            ParameterValue = parameterValue;
            if (parameterValue != null)
            {
                Buffer.BlockCopy(parameterValue, 0, API_IdentifierSpecificData, 5, parameterValue.Length);
            }
        }

        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "AT Command Response"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            //FrameID 
            FrameID = data[1];

            //AT_Command
            AT_Command = string.Concat((char)data[2], (char)data[3]);

            //CommandStatusOption
            CommandStatusOption = (CommandStatus)data[4];

            if (data.Length > 5)
            {
                ParameterValue = new byte[data.Length - 5];
                Buffer.BlockCopy(data, 5, ParameterValue, 0, ParameterValue.Length);
            }
        }

        #endregion
    }
}
