using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.ComLayer
{
    public interface IComLayer : IDisposable
    {
        #region Members

        string Title { get; set; }

        bool IsConnected { get; }

        DateTime CreationTime { get; set; }
        DateTime? LastRX_Time { get; }
        DateTime? LastTX_Time { get; }

        Tunnel ParentTunnel { get; }

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
