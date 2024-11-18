using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.VCT.ComLayer;

namespace Maba.VCT.DIGI.APIProtocol
{
    public class RemoteEndpoint : ComLayer.IComLayer, IComparable
    {

        #region public properties
        public byte[] MAC { get; private set; }
        public long MAC64Bit { get; private set; }
        public string Node_Ideintification { get; private set; }

        public APIProtocol ParentProtocol { get; private set; }

        #endregion

        #region ctor

        public RemoteEndpoint(byte[] mac, string NI, APIProtocol p, ComLayer.Tunnel parentTunnel)
        {
            Node_Ideintification = NI;
            CreationTime = DateTime.UtcNow;
            MAC = mac;
            Title = "My MAC Is:" + ByteArryToString(MAC) + "Parent " + p.InternalComLayer.Title;
            ParentProtocol = p;
            MAC64Bit = 0;
            for (int i = 0; i < MAC.Length; i++)
            {
                MAC64Bit += (long)(MAC[i] * Math.Pow(8 - i, 16));
            }

            this.ParentTunnel = parentTunnel;
        }

        #endregion

        #region Events

        public void SendString(string s)
        {
            throw new NotImplementedException();
        }

        public event ComLayer.DataReceivedDelegate DataReceived;
        public event ComLayer.LayerDestroyedDelegate LayerClosed;

        #endregion

        #region internal methods

        internal void HandlePacket(Packets.APIPacket p)
        {
            if (p is Packets.ZigBeeReceivePacket)
            {
                LastRX_Time = DateTime.UtcNow;

                if (DataReceived != null)
                {
                    var dataP = p as Packets.ZigBeeReceivePacket;
                    DataReceived(this, new ComLayer.DataReceivedEventArgs(dataP.RecivedData, 0, dataP.RecivedData.Length));
                }
            }
        }

        internal bool CompareMAC(byte[] mac)
        {
            if (mac == null || mac.Length != this.MAC.Length)
                return false;

            for (int i = 0; i < MAC.Length; i++)
            {
                if (this.MAC[i] != mac[i])
                    return false;
            }

            return true;
        }

        internal string ByteArryToString(byte[] _mac)
        {
            StringBuilder sb = new StringBuilder();

            for (int i = 0; i < _mac.Length; i++)
            {
                sb.Append(_mac[i].ToString("X2"));
            }
            return sb.ToString();
        }

        #endregion

        #region IComLayer members

        public DateTime? LastRX_Time { get; private set; }
        public DateTime? LastTX_Time { get; private set; }
        public string Title { get; set; }
        public DateTime CreationTime { get; set; }

        public bool IsConnected
        {
            get { return this.ParentProtocol != null && ParentProtocol.IsConnected; }
        }

        public object State { get; set; }

        public Tunnel ParentTunnel { get; private set; }

        public void Open()
        {
        }

        public void Close()
        {
            if (LayerClosed != null)
            {
                LayerClosed(this, new ComLayer.DestroyedEventArgs());
            }
        }

        public void SendBytes(byte[] b, int offset, int count)
        {
            this.LastTX_Time = DateTime.UtcNow;

            var _b = new byte[count];
            Buffer.BlockCopy(b, offset, _b, 0, _b.Length);
            var p = new Packets.Transmit_Request(MAC, new byte[] { 0xFF, 0xFE }, _b);

            ParentProtocol.SendPacket(p);
        }

        public void SendBytes(byte[] b)
        {
            this.SendBytes(b, 0, b.Length);
        }

        public void Dispose()
        {
            Close();

            ParentProtocol = null;

            LayerClosed = null;
        }

        #endregion

        #region overrdein from object

        public override int GetHashCode()
        {
            return base.GetHashCode();
        }

        public override bool Equals(object obj)
        {
            if (obj is RemoteEndpoint)
            {
                return this.MAC64Bit == ((RemoteEndpoint)obj).MAC64Bit;
            }

            return false;
        }

        #endregion

        #region IComparable

        public int CompareTo(object obj)
        {
            return MAC64Bit.CompareTo(((RemoteEndpoint)obj).MAC64Bit);
        }

        #endregion
    }
}
