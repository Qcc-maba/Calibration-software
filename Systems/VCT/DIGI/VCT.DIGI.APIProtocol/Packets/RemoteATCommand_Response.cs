using System;
namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class RemoteATCommand_Response : APIPacket_FramedID
    {
        #region CONSTANT
        public const byte FRAME_TYPE = 0x97;
        #endregion

        #region properties

        //public byte FrameID { get; private set; }
        public string AT_Command { get; private set; }
        public byte[] DestAddress_16_Bit = new byte[2];
        public byte[] DestAddress_64_Bit = new byte[8];
        public CommandStauses CommandStatus { get; private set; }
        public byte[] CommandData { get; private set; }

        #endregion

        #region Enums
        public enum CommandStauses : byte
        {
            OK = 0x00,
            Error = 0x01,
            InvalidCommand = 0x02,
            InvalidParameter = 0x03,
            TxFailure = 0x04
        }
        #endregion

        #region Ctor

        public RemoteATCommand_Response(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return " Response AT Command"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            //FRAME_TYPE= data[1];
            FrameID = data[0];
            for (int i = 2; i < 10; i++)
            {
                DestAddress_64_Bit[i - 2] = data[i];
            }
            DestAddress_16_Bit[0] = data[10];
            DestAddress_16_Bit[1] = data[11];
            AT_Command = string.Concat((char)data[12], (char)data[13]);
            CommandStatus = (CommandStauses)data[14];
            if (data.Length > 15)
            {
                CommandData = new byte[data.Length - 15];
                Buffer.BlockCopy(data, 15, CommandData, 0, CommandData.Length);
            }
        }

        #endregion
    }
}
