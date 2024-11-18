
namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public class Transmit_Status : APIPacket_FramedID
    {
        #region CONSTANT

        public const byte FRAME_TYPE = 0x8b;

        #endregion

        #region properties
        //public byte FrameID { get; private set; }
        public byte[] DestAddress_16_Bit = new byte[2];
        public byte TransmitRetryCount { get; private set; }
        public DeliveryStatus DeliveryStatusOption { get; private set; }
        public DiscoveryStatus DiscoveryStatusOption { get; private set; }
        #endregion

        #region Enums
        public enum DeliveryStatus : byte
        {
            Success = 0x00,
            AnExpected_MAC_AcknoeledgementNeverOccured = 0x01,
            CCA_Filure = 0x02,
            PacketWasPurgedWithoutBeuingTransmitted = 0x03,
            PhisicalErrorOnTheInterfaceWithTheWifiTransciever = 0x04,
            NoBuffers = 0x18,
            ExpectedNetworkAcknowledgementNeverOccurred = 0x21,
            NotJoinedToNetwork = 0x22,
            SelfAddressed = 0x23,
            AddressNotFound = 0x24,
            RouteNotFound = 0x25,
            BroadcastRelayWasNotHeard = 0x26,
            InvalidBindingTableIndex = 0x2B,
            InvalidEndpoint = 0x2C,
            SoftwareErrorOccurred = 0x31,
            ResourceError = 0x32,
            DataPayloadTooLarge = 0x74,
            ClientSocketCreationAttemptFailed = 0x76,
            KeyNotautorized = 0xBB
        }

        public enum DiscoveryStatus : byte
        {
            NoDiscoveryOverhead = 0x00,
            AddressDiscovery = 0x01,
            RouteDiscovery = 0x02,
            AddressAndRoute = 0x03,
            ExtendedTimeoutDiscovery = 0x40
        }
        #endregion

        #region Ctor
        public Transmit_Status(byte[] data)
            : base(data)
        {
        }
        #endregion

        #region APIPacket members

        public override string Title
        {
            get { return "Transmit Status"; }
        }


        public override byte API_FrameType
        {
            get { return FRAME_TYPE; }
        }

        protected override void ParseIdentifierSpecificData(byte[] data)
        {
            FrameID = data[1];

            DestAddress_16_Bit[0] = data[2];
            DestAddress_16_Bit[1] = data[3];
            TransmitRetryCount = data[4];
            if (data.Length > 5)
            {
                DeliveryStatusOption = (DeliveryStatus)data[5];
                DiscoveryStatusOption = (DiscoveryStatus)data[6];
            }
        }
        #endregion
    }
}