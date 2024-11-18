using System;
using System.ComponentModel;
using System.Globalization;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{    
    public class ATCommand : APIPacket_FramedID
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x08;

        #endregion

        #region properties

        public string AT_Command { get; private set; }

        public byte[] ParameterValue { get; private set; }

        #endregion

        #region ctors(s)

        public ATCommand(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        public ATCommand(byte frameID, string aTCommand, byte[] parameterValue)
        {
            API_IdentifierSpecificData = new byte[4 + (parameterValue == null ? 0 : parameterValue.Length)];

            API_IdentifierSpecificData[0] = FRAME_TYPE;

            // FrameID
            SetFrameID(frameID);

            //ATCommand
            AT_Command = aTCommand;
            API_IdentifierSpecificData[2] = (byte)aTCommand[0];
            API_IdentifierSpecificData[3] = (byte)aTCommand[1];

            //ParameterValue
            ParameterValue = parameterValue;
            if (parameterValue != null)
            {
                Buffer.BlockCopy(parameterValue, 0, API_IdentifierSpecificData, 4, parameterValue.Length);
            }
        }

        public ATCommand(string aTCommand, byte[] parameterValue)
            : this(0, aTCommand, parameterValue)
        {

        }

        public ATCommand(string ATCommand)
            : this(0, ATCommand, null)
        {

        }

        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "AT Command"; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            SetFrameID(data[1]);

            AT_Command = string.Concat((char)data[2], (char)data[3]);
            if (data.Length > 4)
            {
                ParameterValue = new byte[data.Length - 4];
                Buffer.BlockCopy(data, 4, ParameterValue, 0, ParameterValue.Length);
            }
        }

        #endregion
    }
}
