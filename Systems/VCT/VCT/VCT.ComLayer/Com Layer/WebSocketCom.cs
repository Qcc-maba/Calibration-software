using System;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Text;
using System.Threading;

namespace Maba.VCT.ComLayer.Com_Layer
{
    public class WebSocketCom : IComLayer
    {
        #region properties
        public string Title { get; set; }
        public DateTime CreationTime { get; set; }
        public bool ReceiveFlag = true;
        #endregion

        #region WebSocket members

        public WebSocket WebSocket { get; private set; }
        private readonly CancellationTokenSource cancellationSource;
        private byte[] _Buffer = new byte[8192];

        #endregion

        #region Events

        public event DataReceivedDelegate DataReceived;
        public event LayerDestroyedDelegate LayerClosed;

        #endregion

        #region ctor
        //Server
        public WebSocketCom(WebSocket websocketClient)
        {
            this.WebSocket = websocketClient;
            this.CreationTime = DateTime.UtcNow;
        }

        #endregion

        #region IComLayer members

        public DateTime? LastRX_Time { get; private set; }

        public DateTime? LastTX_Time { get; private set; }

        public bool IsConnected
        {
            get { return (WebSocket != null && WebSocket.State == WebSocketState.Open); }
        }

        public Tunnel ParentTunnel { get; private set; }

        public void SendBytes(byte[] b)
        {
            SendBytes(b, 0, b.Length);
        }
        public async void SendBytes(byte[] b, int offset, int count)
        {
            if (WebSocket != null && WebSocket.State == WebSocketState.Open)
            {
                await WebSocket.SendAsync(new ArraySegment<byte>(b, offset, count), WebSocketMessageType.Text, true, CancellationToken.None);
            }
        }
        public void SendString(string s)
        {
            if (!string.IsNullOrEmpty(s))
            {
                byte[] b = Encoding.UTF8.GetBytes(s);
                SendBytes(b, 0, b.Length);
            }
        }


        public void Open()
        {

        }


        public async void WebSoketDataReceived()
        {
            try
            {
                if (IsConnected && ReceiveFlag)
                {
                    ReceiveFlag = false;
                    WebSocketReceiveResult result = await WebSocket.ReceiveAsync(
                               new ArraySegment<byte>(_Buffer), CancellationToken.None);
                    if (result.Count > 0)
                    {
                        LastRX_Time = DateTime.Now;

                        if (result.MessageType == WebSocketMessageType.Close)
                        {
                            await WebSocket.CloseAsync(WebSocketCloseStatus.NormalClosure,
                                "Closing", CancellationToken.None);
                            Close();
                        }
                        else
                        {
                            var message = Encoding.UTF8.GetString(_Buffer, 0, result.Count);
                            Console.WriteLine($"Received from client: {message}");
                            if (DataReceived != null)
                            {
                                DataReceived(this, new DataReceivedEventArgs(message));
                            }
                        }
                    }
                    ReceiveFlag = true;
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
                Close();
            }
        }

        public void Close()
        {
            try
            {
                cancellationSource.Cancel();
                if (WebSocket?.State == WebSocketState.Open)
                {
                    WebSocket.CloseAsync(
                        WebSocketCloseStatus.NormalClosure,
                        "Server shutting down",
                        CancellationToken.None).Wait();
                }

            }
            catch (Exception ex)
            {
                throw new WebSocketException("Failed to stop server", ex);
            }
            try
            {
                if (LayerClosed != null)
                {
                    LayerClosed(this, new DestroyedEventArgs());
                }
            }
            catch { }
        }

        public void Dispose()
        {
            Close();
        }
        #endregion

    }
}
