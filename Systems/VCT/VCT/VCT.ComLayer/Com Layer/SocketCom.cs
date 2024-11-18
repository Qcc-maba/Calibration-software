using Microsoft.SqlServer.Server;
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Maba.VCT.ComLayer
{
    public class SocketCom : IComLayer
    {
        #region properties
        public string Title { get; set; }
        public DateTime CreationTime { get; set; }


        #region Test
        TcpClient tcpClient;
        private readonly string _host;
        private readonly int _port;
        private NetworkStream _networkStream;
        private StreamWriter _streamWriter;
        private StreamReader _streamReader;
        #endregion

        //public NetworkStream NetworkStream { get; private set; }
        //private bool SendFlag = true;
        #endregion

        #region  Event
        public event DataReceivedDelegate DataReceived;
        #endregion

        #region ctor

        public SocketCom(Socket clientSocket, ComLayer.Tunnel parentTunnel)
        {
            this.clientSocket = clientSocket;
            this.CreationTime = DateTime.UtcNow;
            this.Title = clientSocket.RemoteEndPoint.ToString();

            this.ParentTunnel = parentTunnel;
        }

        public SocketCom(string address, int port, ComLayer.Tunnel parentTunnel)
        {
            this.clientSocket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            this.CreationTime = DateTime.UtcNow;
            this.clientSocket.ReceiveTimeout = 300;
            this.clientSocket.SendTimeout = 300;
            this.clientSocket.Connect(address, port);

            this.Title = clientSocket.RemoteEndPoint.ToString();
            this.ParentTunnel = parentTunnel;
        }


        #endregion

        #region Members
        private int index = 0;
        private byte[] _Buffer = new byte[8192];
        private Socket clientSocket;

        #endregion

        #region IComLayer members

        public DateTime? LastRX_Time { get; private set; }

        public DateTime? LastTX_Time { get; private set; }

        public bool IsConnected
        {
            get { return clientSocket != null && clientSocket.Connected; }
        }

        public Tunnel ParentTunnel { get; private set; }

        public event LayerDestroyedDelegate LayerClosed;

        public void SendBytes(byte[] b, int offset, int count)
        {
            if (clientSocket != null)
            {
                lock (clientSocket)
                {
                    LastTX_Time = DateTime.UtcNow;
                    clientSocket.Send(b, offset, count, SocketFlags.None);
                };
            }
        }

        public void SendBytes(byte[] b)
        {
            SendBytes(b, 0, b.Length);
        }

        public void Open()
        {
            if (!clientSocket.Connected)
                throw new Exception("Socket is closed!");
            clientSocket.BeginReceive(_Buffer, 0, _Buffer.Length, SocketFlags.None, new AsyncCallback(recived_callback), clientSocket);
        }
        public void Close()
        {
            var s = clientSocket;
            if (s != null)
            {
                clientSocket = null;
                try
                {
                    s.Shutdown(SocketShutdown.Both);
                    s.Close();
                }
                catch { }

                try
                {
                    if (LayerClosed != null)
                    {
                        LayerClosed(this, new DestroyedEventArgs());
                    }
                }
                catch { }
            }
        }

        #endregion

        #region Private methods

        private void recived_callback(IAsyncResult ar)
        {
            if (clientSocket == null)
                return;

            try
            {
                var lastRead = clientSocket.EndReceive(ar);
                if (lastRead > 0)
                {
                    LastRX_Time = DateTime.UtcNow;

                    index += lastRead;

                    if (DataReceived != null)
                    {
                        var e1 = new DataReceivedEventArgs(_Buffer, 0, lastRead);
                        DataReceived(this, e1);
                    }
                    index = 0;
                    clientSocket.BeginReceive(_Buffer, 0, _Buffer.Length, SocketFlags.None, new AsyncCallback(recived_callback), clientSocket);
                }
                else
                {
                    Close();
                }
            }


            catch
            {
                Close();
            }
        }
        #endregion

        #region IDisposable members

        public void Dispose()
        {
            Close();

            LayerClosed = null;
            DataReceived = null;
        }
        public void Connect()
        {
            if (tcpClient == null)
            {
                tcpClient = new TcpClient();
            }
            tcpClient.Connect(_host, _port);
            tcpClient.ReceiveTimeout = 100;

        }
        public async void SendString(string s)
        {
            SendBytes(ASCIIEncoding.Default.GetBytes(s + Environment.NewLine));
        }

        #endregion
    }
}
