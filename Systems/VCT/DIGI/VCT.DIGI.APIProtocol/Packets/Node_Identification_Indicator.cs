using System;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class Node_Identification_Indicator : APIPacket
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x95;

        #endregion

        #region properties

        public byte[] DestAddress_64_BitSource = new byte[8];
        public byte[] DestAddress_16_BitSource = new byte[2];
        public ReceiveOptions _receiveOptions { get; private set; }
        public byte[] DestAddress_16_BitRemote = new byte[2];
        public byte[] DestAddress_64_BitRemote = new byte[8];
        public byte[] NI_String { get; private set; }
        public byte[] Parent16BitAddress = new byte[2];
        public DeviceType _deviceType { get; private set; }
        public SourceEvent _sourceEvent { get; private set; }
        public byte[] DigiProfileID = new byte[2];
        public byte[] ManufacturerID = new byte[2];

        #endregion

        #region Enums
        public enum ReceiveOptions : byte
        {
            PacketAcknowledged = 0x01,
            Packet_was_a_broadcast_packet = 0x02,
            Packet_encrypted_with_APS_escryption = 0x20,
            Packet_was_send_from_an_end_device = 0x40,
        }

        public enum DeviceType : byte
        {
            Coordinator = 0x00,
            Router = 0x01,
            EndDevice = 0x02,
        }

        public enum SourceEvent : byte
        {
            NI_PushButtonEvent = 0x01,
            JoiningEventOccurred = 0x02,
            PowerCycleEventOccurred = 0x03,
        }
        #endregion

        #region Ctor

        public Node_Identification_Indicator(byte[] api_UnescapteFrameData)
            : base(api_UnescapteFrameData)
        {
        }

        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return " Node Identification Indicator "; }
        }

        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            for (int i = 1; i < 9; i++)
            {
                DestAddress_64_BitSource[i - 1] = data[i];
            }
            DestAddress_16_BitSource[0] = data[9];
            DestAddress_16_BitSource[1] = data[10];
            _receiveOptions = (ReceiveOptions)data[11];
            DestAddress_16_BitRemote[0] = data[12];
            DestAddress_16_BitRemote[1] = data[13];

            for (int i = 14; i < 22; i++)
            {
                DestAddress_64_BitRemote[i - 14] = data[i];
            }

            if (data.Length > 31)
            {
                NI_String = new byte[data.Length - 31];
                Buffer.BlockCopy(data, 22, NI_String, 0, NI_String.Length);
            }
            Parent16BitAddress[0] = data[NI_String.Length + 23];
            Parent16BitAddress[1] = data[NI_String.Length + 24];
            _deviceType = (DeviceType)data[NI_String.Length + 25];
            _sourceEvent = (SourceEvent)data[NI_String.Length + 26];
            DigiProfileID[0] = data[NI_String.Length + 27];
            DigiProfileID[1] = data[NI_String.Length + 28];
            ManufacturerID[0] = data[NI_String.Length + 29];
            ManufacturerID[1] = data[NI_String.Length + 30];
        }

        #endregion
    }
}
