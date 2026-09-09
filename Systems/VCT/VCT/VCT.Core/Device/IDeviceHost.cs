using Maba.VCT.ComLayer;
using Maba.VCT.Common;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace Maba.VCT.Core.Device
{
    /// <summary>
    /// A connected device as the rest of the server sees it — identified by <see cref="SN"/> and
    /// reachable over an <see cref="IComLayer"/>. Implemented by both the hardware host and the
    /// WebSocket (web app) host.
    /// </summary>
    public interface IDeviceHost : IDisposable
    {
        DateTime IdentificationDate { get;  set; }
        string SN { get; }
        bool IsConnected { get; }
        IComLayer InternalComLayer { get; }
        IDeviceBL BL { get; }
        void Disconnect();
        void ReplaceComLayer(IComLayer value);
        void SendPacket(IPacket p);
    }
}
