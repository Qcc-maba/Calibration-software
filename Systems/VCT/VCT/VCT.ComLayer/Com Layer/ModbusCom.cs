using Modbus.Device;
using System;
using System.Collections;
using System.IO.Ports;
using System.Text;

namespace Maba.VCT.ComLayer
{
    public class ModbusCom : IComLayer
    {
        #region Members
        public ModbusSerialMaster SerialMaster { get; private set; }
        public DateTime? LastRX_Time { get; private set; }
        public DateTime? LastTX_Time { get; private set; }
        public string Title { get; set; }
        public DateTime CreationTime { get; set; }
        public string PortName { get; private set; }
        public int BaudRate { get; private set; }
        public Tunnel ParentTunnel { get; private set; }
        protected SerialPort _SerialPort { get; set; }
        public bool IsConnected
        {
            get { return _SerialPort != null && _SerialPort.IsOpen; }
        }
        public byte SlaveID { get; private set; }
        public ushort NumberOfReading { get; private set; }
        #endregion

        #region Ctor

        public ModbusCom(string portName, int baudRate, Tunnel parentTupple = null)
        {
            PortName = portName;
            BaudRate = baudRate;
            this.Title = String.Format("Port Name:{0} , BaudeRate:{1}", portName, baudRate);
            this.CreationTime = DateTime.UtcNow;
            this.ParentTunnel = parentTupple;
        }

        #endregion

        #region Events

        public event DataReceivedDelegate DataReceived;
        public event LayerDestroyedDelegate LayerClosed;

        #endregion

        #region Public Methods

        public virtual void Open()
        {
            if (_SerialPort != null)
                throw new Exception("Already Open");

            _SerialPort = new SerialPort();
            _SerialPort.PortName = PortName;
            _SerialPort.BaudRate = BaudRate;
            _SerialPort.DataBits = 8;
            _SerialPort.StopBits = StopBits.One;
            _SerialPort.Parity = Parity.None;
            SlaveID = 1;
            NumberOfReading = 2;

            try
            {
                _SerialPort.Open();
                SerialMaster = ModbusSerialMaster.CreateRtu(_SerialPort);
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
        public void Dispose()
        {
            Close();

            LayerClosed = null;
            DataReceived = null;
        }
        public void SendBytes(byte[] b, int offset, int count)
        {
            ushort[] response = SerialMaster.ReadHoldingRegisters(SlaveID, BitConverter.ToUInt16(b, offset), NumberOfReading);
            if (DataReceived != null)
            {
                var e1 = new DataReceivedEventArgs(response, offset, count);
                DataReceived(this, e1);
            }
        }
        public void SendBytes(byte[] b)
        {
            SendBytes(b, 0, b.Length);
        }

        public void SendString(string s)
        {
            ushort result = ushort.Parse(s);
            ushort[] response = SerialMaster.ReadHoldingRegisters(SlaveID, result, NumberOfReading);

            if (DataReceived != null)
            {
                var e1 = new DataReceivedEventArgs(ConvertRegistersToFloat(response[0], response[1]), 0, response.Length);
                DataReceived(this, e1);
            }
        }

        #endregion
        #region Private Methods
        static float ConvertRegistersToFloat(ushort msw, ushort lsw)
        {
            // Combine registers into a 32-bit integer
            uint combined = ((uint)msw << 16) | lsw;

            // Convert to bytes and then to a float
            byte[] bytes = BitConverter.GetBytes(combined);
            return BitConverter.ToSingle(bytes, 0);
        }
        #endregion
    }
}
