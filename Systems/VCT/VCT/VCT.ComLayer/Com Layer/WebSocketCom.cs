using Maba.VCT.Libs.Trace;
using System;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

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

        /// <summary>Cancels <see cref="RunReceiveLoopAsync"/> when <see cref="Close"/> is called.</summary>
        public CancellationToken ReadLoopCancellation => cancellationSource.Token;

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
            this.cancellationSource = new CancellationTokenSource();
            Console.WriteLine($"[WS] WebSocketCom created at {CreationTime:yyyy-MM-dd HH:mm:ss}");
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
            try
            {
                if (WebSocket != null && WebSocket.State == WebSocketState.Open)
                {
                    await WebSocket.SendAsync(new ArraySegment<byte>(b, offset, count), WebSocketMessageType.Text, true, CancellationToken.None);
                    LastTX_Time = DateTime.Now;
                }
                else
                {
                    Console.WriteLine($"[WS Send] SKIP - socket not open (state={WebSocket?.State})");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WS Send] ERROR: {ex.Message}");
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


        /// <summary>
        /// Polls one incoming frame (legacy). Prefer <see cref="RunReceiveLoopAsync"/> so client messages are processed immediately.
        /// </summary>
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
                            Console.WriteLine("[WS RX] Client requested close");
                            await WebSocket.CloseAsync(WebSocketCloseStatus.NormalClosure,
                                "Closing", CancellationToken.None);
                            Close();
                        }
                        else
                        {
                            var message = Encoding.UTF8.GetString(_Buffer, 0, result.Count);
                            Console.WriteLine($"[WS RX] {message}");
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
                Console.WriteLine($"[WS RX] ERROR: {e.Message}");
                Close();
            }
        }

        /// <summary>Reads WebSocket text frames until close/cancel and raises <see cref="DataReceived"/> for each message.</summary>
        public async Task RunReceiveLoopAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                while (WebSocket != null && WebSocket.State == WebSocketState.Open)
                {
                    WebSocketReceiveResult result;
                    try
                    {
                        result = await WebSocket
                            .ReceiveAsync(new ArraySegment<byte>(_Buffer), cancellationToken)
                            .ConfigureAwait(false);
                    }
                    catch (ObjectDisposedException)
                    {
                        break;
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (WebSocketException wsex)
                    {
                        Console.WriteLine($"[WS RX] WebSocketException: {wsex.Message}");
                        break;
                    }

                    LastRX_Time = DateTime.Now;

                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        Console.WriteLine("[WS RX] Client requested close");
                        try
                        {
                            if (WebSocket.State == WebSocketState.Open || WebSocket.State == WebSocketState.CloseReceived)
                            {
                                await WebSocket.CloseAsync(
                                    WebSocketCloseStatus.NormalClosure,
                                    "Closing",
                                    CancellationToken.None).ConfigureAwait(false);
                            }
                        }
                        catch (Exception ex)
                        {
                            Tracer.Info("[WS] CloseAsync after client close: {0}", ex.Message);
                        }

                        Close();
                        break;
                    }

                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        // One logical message may span multiple frames until EndOfMessage.
                        var sb = new StringBuilder();
                        WebSocketReceiveResult r = result;
                        while (true)
                        {
                            if (r.Count > 0)
                            {
                                sb.Append(Encoding.UTF8.GetString(_Buffer, 0, r.Count));
                            }

                            if (r.EndOfMessage)
                            {
                                break;
                            }

                            r = await WebSocket
                                .ReceiveAsync(new ArraySegment<byte>(_Buffer), cancellationToken)
                                .ConfigureAwait(false);

                            if (r.MessageType == WebSocketMessageType.Close)
                            {
                                Console.WriteLine("[WS RX] Client requested close (mid-text)");
                                try
                                {
                                    if (WebSocket.State == WebSocketState.Open || WebSocket.State == WebSocketState.CloseReceived)
                                    {
                                        await WebSocket.CloseAsync(
                                            WebSocketCloseStatus.NormalClosure,
                                            "Closing",
                                            CancellationToken.None).ConfigureAwait(false);
                                    }
                                }
                                catch (Exception ex)
                                {
                                    Tracer.Info("[WS] CloseAsync (mid-text): {0}", ex.Message);
                                }

                                Close();
                                return;
                            }

                            if (r.MessageType != WebSocketMessageType.Text)
                            {
                                Console.WriteLine($"[WS RX] Non-text continuation (type={r.MessageType}) — dropping partial message.");
                                break;
                            }
                        }

                        var message = sb.ToString();
                        if (message.Length > 0)
                        {
                            Console.WriteLine($"[WS RX] {message}");
                            DataReceived?.Invoke(this, new DataReceivedEventArgs(message));
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"[WS RX] RunReceiveLoopAsync: {e.Message}");
            }
            finally
            {
                if (WebSocket != null &&
                    (WebSocket.State == WebSocketState.Open || WebSocket.State == WebSocketState.CloseReceived))
                {
                    try
                    {
                        Close();
                    }
                    catch (Exception ex)
                    {
                        Tracer.Info("[WS] Close in RunReceiveLoopAsync finally: {0}", ex.Message);
                    }
                }
            }
        }

        public void Close()
        {
            Console.WriteLine($"[WS Close] Closing WebSocket (state={WebSocket?.State})");
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
                Console.WriteLine("[WS Close] WebSocket closed OK");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WS Close] ERROR: {ex.Message}");
            }
            try
            {
                if (LayerClosed != null)
                {
                    LayerClosed(this, new DestroyedEventArgs());
                }
            }
            catch (Exception ex)
            {
                Tracer.Info("[WS] LayerClosed handler: {0}", ex.Message);
            }
        }

        public void Dispose()
        {
            Close();
        }
        #endregion

    }
}
