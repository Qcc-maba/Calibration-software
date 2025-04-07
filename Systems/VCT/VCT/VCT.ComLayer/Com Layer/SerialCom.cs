using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Maba.VCT.ComLayer
{
    public class SerialCom : IComLayer
    {
        #region properties

        public DateTime? LastRX_Time { get; private set; }

        public DateTime? LastTX_Time { get; private set; }

        public string Title { get; set; }

        public DateTime CreationTime { get; set; }

        public string PortName { get; private set; }

        public int BaudRate { get; private set; }
        public int Timeout { get; private set; }

        #endregion

        #region  Event
        public event DataReceivedDelegate DataReceived; // DataReceivedEventArgs
        #endregion

        #region members
        private byte[] _Buffer = new byte[8192];
        protected SerialPort _SerialPort { get; set; }
        int writeIndex = 0;
        #endregion

        #region ctor

        public SerialCom(string portName, int baudRate,int timeout, Tunnel parentTupple = null)
        {
            PortName = portName;
            BaudRate = baudRate;
            Timeout = timeout;
            this.Title = String.Format("Port Name:{0} , BaudeRate:{1}", portName, baudRate);
            this.CreationTime = DateTime.UtcNow;
            this.ParentTunnel = parentTupple;
        }

        #endregion

        #region private methods

        protected void _SerialPort_DataReceived(object sender, SerialDataReceivedEventArgs e)
        {
            lock (_SerialPort)
            {
                try
                {
                    Thread.Sleep(_SerialPort.ReadTimeout);
                    int offset = 0;
                    var lastRead = _SerialPort.Read(_Buffer, offset,_SerialPort.BytesToRead);
                    //var lastRead = _SerialPort.ReadLine();
                    writeIndex += lastRead;
                    if (writeIndex > 0)
                    {
                        //writeIndex += lastRead;
                        LastRX_Time = DateTime.UtcNow;


                        if (DataReceived != null)
                        {
                            var e1 = new DataReceivedEventArgs(_Buffer, offset, writeIndex);
                            //var e1 = new DataReceivedEventArgs(lastRead);
                            DataReceived(this, e1);
                        }
                        writeIndex = 0;
                        _SerialPort.DiscardInBuffer();
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"IOException: {ex.Message}");
                }
            }
        }

        #endregion

        #region IComLayer members

        public bool IsConnected
        {
            get { return _SerialPort != null && _SerialPort.IsOpen; }
        }

        public object State { get; set; }

        public Tunnel ParentTunnel { get; private set; }

        public event LayerDestroyedDelegate LayerClosed;

        public void SendBytes(byte[] b, int offset, int count)
        {
            lock (_SerialPort)
            {
                Thread.Sleep(_SerialPort.WriteTimeout);
                LastTX_Time = DateTime.UtcNow;
                _SerialPort.Write(b, offset, count);
            };
        }

        public void SendBytes(byte[] b)
        {
            SendBytes(b, 0, b.Length);
        }

        public void SendString(string s)
        {
            try
            {
                lock (_SerialPort)
                {
                    LastTX_Time = DateTime.UtcNow;
                    _SerialPort.WriteLine(s);
                };
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message.ToString());
            }

        }

        public virtual void Open()
        {
            if (_SerialPort != null)
                throw new Exception("Already Open");

            _SerialPort = new SerialPort();
            _SerialPort.DataReceived += _SerialPort_DataReceived;
            _SerialPort.PortName = PortName;
            _SerialPort.BaudRate = BaudRate;
            _SerialPort.ReadTimeout = Timeout;

            //_SerialPort.NewLine = "\r\n";
            //_SerialPort.DataBits = 8;
            //_SerialPort.StopBits = StopBits.Two;
            _SerialPort.DtrEnable = true;
            _SerialPort.RtsEnable = true;
            //_SerialPort.Handshake = Handshake.None;

            //_SerialPort.Parity = Parity.None;



            try
            {
                if (!_SerialPort.IsOpen)
                {
                    _SerialPort.Open();
                }
            }
            catch (Exception)
            {
                throw new Exception("Already Open");
            }
        }

        public virtual void Close()
        {
            var s = _SerialPort;

            if (s != null)
            {
                _SerialPort = null;

                s.DataReceived -= _SerialPort_DataReceived;
                try
                {
                    if (s.IsOpen)
                    {
                        s.Close();
                    }
                }
                catch { }
            }

            if (LayerClosed != null)
            {
                LayerClosed(this, new DestroyedEventArgs());
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

        #endregion
    }
}
