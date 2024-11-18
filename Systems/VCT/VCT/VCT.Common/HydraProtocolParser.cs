using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    public class Hydra2ProtocolParser : IProtocolParser
    {
        #region Members

        private byte[] _Buffer = new byte[8192];
        private int writeIndex = 0;
        private byte[] Delimeter = new byte[] { 0x0d, 0x0a };

        #endregion

        #region Properties

        public PacketDelegate OnPacket = null;

        #endregion

        #region IProtocol Methods

        public void OnData(byte[] buffer, int offset, int count)
        {
            Buffer.BlockCopy(buffer, offset, _Buffer, writeIndex, count);
            writeIndex += count;
            if (ASCIIEncoding.ASCII.GetString(_Buffer).Contains("FLUK"))
            {
                ParsePackets();
            }
            else if (Locate(_Buffer, Delimeter))
            {
                ParsePackets();
            }
        }
        private void ParsePackets()
        {
            var packetBytes = new byte[writeIndex];
            Buffer.BlockCopy(_Buffer, 0, packetBytes, 0, packetBytes.Length);
            var p = new Packet(ASCIIEncoding.ASCII.GetString(packetBytes));
            Console.WriteLine("Packet  " + p.ToString());
            OnPacket(this, new PacketEventArgs(p));
            for (int i = 0; i < writeIndex; i++)
            {
                _Buffer[i] = _Buffer[i + writeIndex];
            }

            writeIndex = 0;
            //last_7EIndex = -1;

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

        void IProtocolParser.ParsePackets()
        {
            throw new NotImplementedException();
        }
        #endregion
    }

}
