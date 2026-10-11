using Maba.VCT.Libs.Trace;
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

        /// <summary>
        /// Flow control. Defaults to <see cref="Handshake.None"/> (with DTR/RTS asserted) which suits
        /// SCPI/DTR-DSR instruments such as the 34401A. Set before <see cref="Open"/> if a device needs
        /// software (XON/XOFF) or RTS/CTS flow control.
        /// </summary>
        public Handshake Handshake { get; set; } = Handshake.None;

        #endregion

        #region  Event
        public event DataReceivedDelegate DataReceived; // DataReceivedEventArgs
        #endregion

        #region members
        private byte[] _Buffer = new byte[8192];
        protected SerialPort _SerialPort { get; set; }
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
                    int bytesToRead = _SerialPort.BytesToRead;
                    if (bytesToRead > 0)
                    {
                        var lastRead = _SerialPort.Read(_Buffer, 0, bytesToRead);
                        if (lastRead > 0)
                        {
                            LastRX_Time = DateTime.UtcNow;
                            SerialRxLogger.Append(PortName, _Buffer, 0, lastRead);
                            if (DataReceived != null)
                            {
                                DataReceived(this, new DataReceivedEventArgs(_Buffer, 0, lastRead));
                            }
                        }
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
            _SerialPort.DataBits = 8;
            _SerialPort.StopBits = StopBits.One;
            _SerialPort.Parity = Parity.None;
            _SerialPort.Handshake = this.Handshake;
            _SerialPort.ReadBufferSize = 8192;
            _SerialPort.DtrEnable = true;
            _SerialPort.RtsEnable = true;



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
                    else
                    {
                        CloseDeadStream(s);
                    }
                }
                catch (Exception ex)
                {
                    Tracer.Info("[Serial] Close port {0}: {1}", PortName, ex.Message);
                }
            }

            if (LayerClosed != null)
            {
                LayerClosed(this, new DestroyedEventArgs());
            }
        }

        /// <summary>
        /// The field <see cref="SerialPort"/> keeps its stream in. Looked up once; null if a framework
        /// ever renames it, in which case a dead stream is left to its finalizer, as it always was.
        /// </summary>
        internal static readonly System.Reflection.FieldInfo InternalSerialStreamField =
            typeof(SerialPort).GetField("internalSerialStream",
                System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);

        /// <summary>
        /// MBA-967: closes the OS handle of a port whose device has gone. When a USB-serial adapter
        /// drops, .NET's serial event loop ends and <c>IsOpen</c> turns false while the handle stays
        /// open - and <c>SerialPort.Close</c> then does nothing, because it only closes an open port.
        /// The handle was left for the finalizer to close at some later moment, which may be after
        /// the same COM port has been opened again for the adapter that came back.
        /// </summary>
        internal static void CloseDeadStream(SerialPort port)
        {
            var stream = InternalSerialStreamField?.GetValue(port) as System.IO.Stream;
            if (stream == null) return;

            InternalSerialStreamField.SetValue(port, null);
            try
            {
                stream.Dispose();
            }
            catch (Exception ex)
            {
                // A removed device can fail the last purge on the way out; the handle is closed anyway.
                Tracer.Info("[Serial] Closing dead stream: {0}", ex.Message);
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
