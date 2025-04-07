using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    public class HydraProtocolParser : IProtocolParser
    {
        #region Members

        private byte[] _Buffer = new byte[8192];
        private int writeIndex = 0;
        private byte[] Delimeter = new byte[] { 0x0d, 0x0a };
        #endregion

        #region Properties

        public PacketDelegate OnPacket { get; set; }
        #endregion

        #region IProtocol Methods



        public void OnData(byte[] buffer, int offset, int count)
        {
            Buffer.BlockCopy(buffer, offset, _Buffer, writeIndex, count);
            writeIndex += count;
            ParsePackets();
        }
        private void ParsePackets()
        {
            var packetBytes = new byte[writeIndex];
            Buffer.BlockCopy(_Buffer, 0, packetBytes, 0, packetBytes.Length);
            var packet = new HardwarePacket(ASCIIEncoding.ASCII.GetString(packetBytes));

            OnPacket(this, new PacketEventArgs(packet));
            for (int i = 0; i < writeIndex; i++)
            {
                _Buffer[i] = _Buffer[i + writeIndex];
            }

            writeIndex = 0;
        }
        public void OnData(float floatData)
        {
            var packet = new HardwarePacket(floatData);
            OnPacket(this, new PacketEventArgs(packet));
        }
        #endregion

        #region private methods
        public static bool Locate(byte[] self, byte[] candidate)
        {
            if (IsEmptyLocate(self, candidate))
                return false;

            var list = new List<int>();

            for (int i = 0; i < self.Length; i++)
            {
                if (!IsMatch(self, i, candidate))
                    continue;

                list.Add(i);
            }

            return list.Count != 0;
        }

        static bool IsMatch(byte[] array, int position, byte[] candidate)
        {
            if (candidate.Length > (array.Length - position))
                return false;

            for (int i = 0; i < candidate.Length; i++)
                if (array[position + i] != candidate[i])
                    return false;

            return true;
        }

        static bool IsEmptyLocate(byte[] array, byte[] candidate)
        {
            return array == null
                   || candidate == null
                   || array.Length == 0
                   || candidate.Length == 0
                   || array.All(a => a == 0x00)
                   || candidate.All(a => a == 0x00)
                   || candidate.Length > array.Length;
        }



        #endregion
    }

}
