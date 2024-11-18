using System;
using System.Linq;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;

namespace Maba.VCT.DIGI.APIProtocol.Packets
{
    public abstract class APIPacket
    {
        #region Members
        public bool Escaping { get; private set; }
        #endregion

        #region Enums
        /*
        public enum Frame_Types : byte
        {
            // only in  802.5.14
            /// <summary>
            /// 0x00 - Transmit Request (802.5.14)
            /// </summary>
            Tx_Transmit_Request_64bit = 0x00,
            /// <summary>
            /// 0x01 - Tx (Transmit) Request (802.5.14)
            /// </summary>
            Tx_Transmit_Request_16bit = 0x01,/// <summary>
            /// <summary>
            /// 0x80 - Transmit Recive 64 bit (802.5.14)
            /// </summary>
            Rx_Transmit_Receive_64bit = 0x80,
            /// <summary>
            /// 0x81 - Transmit Recive 16 bit (802.5.14)
            /// </summary>
            Rx_Transmit_Receive_16bit = 0x81,

            // in ZigBee  and Digimash
            /// <summary>
            /// 0x08 - AT Command (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            ATCommand = 0x08,
            /// <summary>
            /// 0x88 - AT Command Response (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            ATCommand_Response = 0x88,
            /// <summary>
            /// 0x17 - Remote AT Command (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            RemoteATCommand = 0x17,
            /// <summary>
            /// 0x97 - Remote AT Command Response (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            RemoteATCommand_Response = 0x97,
            /// <summary>
            /// 0x10 - Transmit Request (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            Transmit_Request = 0x10,
            /// <summary>
            /// 0x90 - ZigBee Receive Common.Packet (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            ZigBeeReceivePacket = 0x90,
            /// <summary>
            /// 0x18b - Transmit Status (802.5.14, Zigbee, DigiMesh)
            /// </summary>
            Transmit_Status = 0x8b,
            Unknown = 0xFF
        }*/

        #endregion

        #region Ctor(s)

        protected internal APIPacket()
        {
            Escaping = true;
        }

        /// <summary>
        /// Entire Common.Packet (7E, Len, FrameData and Checksum)
        /// Usually, for incoming Common.Packet in stream.
        /// </summary>
        /// <param name="api_UnescapteFrameData"></param>
        public APIPacket(byte[] api_UnescapteFrameData)
        {
            Escaping = true;
            if (api_UnescapteFrameData != null && api_UnescapteFrameData.Length >= 4)
            {
                if (CalcCheckSum(api_UnescapteFrameData, 3, api_UnescapteFrameData.Length - 4) != api_UnescapteFrameData[api_UnescapteFrameData.Length - 1])
                {
                    throw new Exception("Packet is invalid");
                }

                //API_FrameType = api_UnescapteFrameData[2];
                API_IdentifierSpecificData = new byte[api_UnescapteFrameData.Length - 4];
                Buffer.BlockCopy(api_UnescapteFrameData, 3, API_IdentifierSpecificData, 0, API_IdentifierSpecificData.Length);
            }
            else
            {
                throw new Exception("Packet is invalid");
            }

            ParseIdentifierSpecificData(API_IdentifierSpecificData);
        }

        #endregion

        #region abstracts properties

        public abstract string Title { get; }

        public abstract byte API_FrameType { get; }

        protected abstract void ParseIdentifierSpecificData(byte[] data);

        #endregion

        #region Properties

        /// <summary>
        /// Frame Data (includes: FrameType, FrameID (when applicable))
        /// </summary>
        /// 
        public byte[] API_IdentifierSpecificData { get; protected set; }

        #endregion

        #region public/protected static Methods

        public static byte CalcCheckSum(byte? frame_Type, byte[] b, int offset, int count)
        {
            if (b == null || count <= 0)
                return 0;

            byte check = 0xff;
            check -= frame_Type.GetValueOrDefault(0);

            for (int i = offset; i < offset + count; i++)
            {
                check -= b[i];
            }
            return check;
        }

        public static byte CalcCheckSum(byte[] b, int offset, int count)
        {
            return CalcCheckSum(null, b, offset, count);
        }

        #endregion

        #region public methods

        public byte[] ToBytes()
        {
            var bytes = new List<byte>();

            bytes.Add(0x7E);

            //Len
            var api_len = API_IdentifierSpecificData.Length;

            bytes.Add((byte)((api_len >> 8) & (0xFF)));
            bytes.Add((byte)(api_len & 0xFF));

            //API_FrameType
            // bytes.Add(API_FrameType);

            //API_FrameData
            for (int i = 0; i < API_IdentifierSpecificData.Length; i++)
            {
                bytes.Add(API_IdentifierSpecificData[i]);
            }

            //checksum
            var temp = CalcCheckSum(API_FrameType, API_IdentifierSpecificData, 1, API_IdentifierSpecificData.Length - 1);
            bytes.Add(CalcCheckSum(API_FrameType, API_IdentifierSpecificData, 1, API_IdentifierSpecificData.Length - 1));

            byte? Temp = null;

            int _countOfDelimetrs = 0;

            var _count = bytes.Count;

            for (int i = 1; i < _count + _countOfDelimetrs; i++)
            {
                if (bytes[i] == 0x11 || bytes[i] == 0x13 || bytes[i] == 0x7D || bytes[i] == 0x7E)
                {
                    _countOfDelimetrs++;
                    Temp = bytes[i];
                    bytes[i] = 0x7D;
                    bytes.Insert(i + 1, (byte)(Temp ^ 0x20));
                }
            }
            return bytes.ToArray();
        }

        #endregion

        #region overriden from Object

        public string PrintPacket()
        {
            return String.Concat(this.ToBytes().Select(b => b.ToString("X2") + " "));
        }

        public override string ToString()
        {
            return String.IsNullOrEmpty(Title) ?
                String.Format("0x{0}", API_FrameType.ToString("X2"))
                : String.Format("0x{0} - {1}", API_FrameType.ToString("X2"), Title);
        }

        #endregion
    }
}
