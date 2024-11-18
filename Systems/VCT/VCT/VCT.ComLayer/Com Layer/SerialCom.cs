using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Text;
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

        #endregion

        #region  Event
        public event DataReceivedDelegate DataReceived; // DataReceivedEventArgs
        #endregion

        #region members
        private byte[] _Buffer = new byte[8192];
        protected SerialPort _SerialPort { get; set; }

        #endregion

        #region ctor

        public SerialCom(string portName, int baudRate, Tunnel parentTupple = null)
        {
            PortName = portName;
            BaudRate = baudRate;
            this.Title = String.Format("Port Name:{0} , BaudeRate:{1}", portName, baudRate);
            this.CreationTime = DateTime.UtcNow;

            this.ParentTunnel = parentTupple;
        }

        #endregion

        #region private methods

        public virtual bool IncomingData(byte[] b, ref int offset, ref int count)
        {
            return true;
        }

        protected void _SerialPort_DataReceived(object sender, SerialDataReceivedEventArgs e)
        {
            lock (_SerialPort)
            {
                var lastRead = _SerialPort.Read(_Buffer, 0, _SerialPort.BytesToRead);
                if (lastRead > 0)
                {
                    LastRX_Time = DateTime.UtcNow;

                    int offset = 0;
                    if (IncomingData(_Buffer, ref offset, ref lastRead))
                    {

                        if (DataReceived != null)
                        {
                            var e1 = new DataReceivedEventArgs(_Buffer, offset, lastRead);
                            DataReceived(this, e1);
                        }
                    }
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
            lock (_SerialPort)
            {
                LastTX_Time = DateTime.UtcNow;
                _SerialPort.WriteLine(s);
            };
        }

        public virtual void Open()
        {
            if (_SerialPort != null)
                throw new Exception("Already Open");

            _SerialPort = new SerialPort();
            _SerialPort.DataReceived += _SerialPort_DataReceived;
            _SerialPort.PortName = PortName;
            _SerialPort.BaudRate = BaudRate;

            try
            {
                _SerialPort.Open();
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
