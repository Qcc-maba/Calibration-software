using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.ComLayer
{
    /// <summary>
    /// A raw byte transport to a device — serial, TCP socket, Modbus or WebSocket. It knows nothing
    /// about the instrument protocol: it only opens/closes the link, sends bytes and raises
    /// DataReceived. Protocol framing happens above, in the device host's parser.
    /// </summary>
    public interface IComLayer : IDisposable
    {
        #region Members

        string Title { get; set; }

        bool IsConnected { get; }
        Tunnel ParentTunnel { get; }

        DateTime CreationTime { get; set; }
        DateTime? LastRX_Time { get; }
        DateTime? LastTX_Time { get; }

        #endregion

        #region Methods

        void Open();

        void Close();

        void SendBytes(byte[] b, int offset, int count);

        void SendBytes(byte[] b);

        void SendString(string s);

        #endregion

        #region Events
        event DataReceivedDelegate DataReceived;

        event LayerDestroyedDelegate LayerClosed;

        #endregion
    }
}
