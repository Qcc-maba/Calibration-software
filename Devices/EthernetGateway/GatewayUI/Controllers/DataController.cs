using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace GatewayUI.Controllers
{
    [RoutePrefix("Data")]
    public class DataController : ApiController
    {
        #region static

        public static Models.DeviceConfig CurrentConfig { get; set; }

        static DataController()
        {
            CurrentConfig = new Models.DeviceConfig()
            {
                DeviceName = "Cyber Rain - Gateway",
                MAC = "",
                IPConfig = new Models.IPAddressConfig()
                {
                    AddressType = Models.IPAddressConfig.AddressTypeOptions.AUTO,
                    IPAddress = "10.0.0.1",
                    Subnet = "255.255.255.0",
                    DefaultGateway = "10.0.0.254",
                    DNS = "10.0.0.33"
                },
                UART = new Models.UARTConfig()
                {
                    Baudrate = 9600,
                    DataBits = 8,
                    FlowControl = Models.UARTConfig.FlowControlOptions.None,
                    Parity = Models.UARTConfig.ParityOptions.None,
                    StopBits = 1
                },
                RemoteServer = new Models.RemoteServerConfig()
                {
                    ServerAddress = "rnd1.glc-service.com",
                    Port = 50000,
                    Interval = 5,
                    Timeout = 300
                }
            };
        }

        #endregion

        [HttpGet]
        [Route("Info")]
        public Models.DeviceInfo GetDeviceInfo()
        {
            return new Models.DeviceInfo()
            {
                DeviceName = CurrentConfig.DeviceName ?? "Cyber Rain - Gateway",
                SocketStatus = "Online",
                FirmwareVersion = "1.21",
                IPAddress = "10.0.0.52",
                MAC = CurrentConfig.MAC,
                SerialStatus = String.Format("{0} {1}-{2}-{3}", CurrentConfig.UART.Baudrate, CurrentConfig.UART.DataBits, CurrentConfig.UART.FlowControl, CurrentConfig.UART.StopBits),
                ServerAddress = CurrentConfig.RemoteServer.ServerAddress,
                ServerPort = CurrentConfig.RemoteServer.Port,
                ServerTotalConnection = 300,
                RSSILevel = 45
            };
        }

        [HttpGet]
        [Route("Config")]
        public Models.DeviceConfig GetDeviceConfig()
        {
            return CurrentConfig;
        }

        [HttpGet]
        [Route("SetName")]
        public bool SetDeviceName(string NewName)
        {
            CurrentConfig.DeviceName = NewName;
            return true;
        }

        [HttpGet]
        [Route("AllocateMAC")]
        public Models.DeviceAllocatedMAC AllocatedMAC(string NewMAC)
        {
            if (String.IsNullOrEmpty(NewMAC))
            {
                var rnd = new Random();
                string mac = "";
                for (int i = 0; i < 6; i++)
                {
                    mac += rnd.Next(0, 255).ToString("X2") + (i < 6 - 1 ? ":" : "");
                }
            }

            var allocatedMAC = new Models.DeviceAllocatedMAC()
            {
                MAC = NewMAC
            };

            CurrentConfig.MAC = NewMAC;

            return allocatedMAC;
        }

        [HttpGet]
        [Route("SaveIPSettings")]
        public bool SaveIPSettings(string type, string sip, string mip, string gip, string dip)
        {
            switch (type)
            {
                case "STATIC":
                    CurrentConfig.IPConfig.AddressType = Models.IPAddressConfig.AddressTypeOptions.STATIC;
                    break;
                case "AUTO":
                    CurrentConfig.IPConfig.AddressType = Models.IPAddressConfig.AddressTypeOptions.AUTO;
                    break;
            }

            CurrentConfig.IPConfig.IPAddress = sip;
            CurrentConfig.IPConfig.Subnet = mip;
            CurrentConfig.IPConfig.DefaultGateway = gip;
            CurrentConfig.IPConfig.DNS = dip;
            return true;
        }

        [HttpGet]
        [Route("SaveSerialSettings")]
        public bool SaveIPSettings(int baudrate, byte bits, string parity, byte sbits, string flow)
        {
            CurrentConfig.UART.Baudrate = baudrate;
            CurrentConfig.UART.DataBits = bits;
            switch (parity)
            {
                default:
                case "None":
                    CurrentConfig.UART.Parity = Models.UARTConfig.ParityOptions.None;
                    break;
                case "Odd":
                    CurrentConfig.UART.Parity = Models.UARTConfig.ParityOptions.Odd;
                    break;
                case "Even":
                    CurrentConfig.UART.Parity = Models.UARTConfig.ParityOptions.Even;
                    break;
            }

            CurrentConfig.UART.StopBits = sbits;

            switch (flow)
            {
                default:
                case "None":
                    CurrentConfig.UART.FlowControl = Models.UARTConfig.FlowControlOptions.None;
                    break;
                case "Hardware":
                    CurrentConfig.UART.FlowControl = Models.UARTConfig.FlowControlOptions.Hardware;
                    break;
                case "XonXoff":
                    CurrentConfig.UART.FlowControl = Models.UARTConfig.FlowControlOptions.XonXoff;
                    break;
            }

            return true;
        }

        [HttpGet]
        [Route("Apply")]
        public bool ApplySettings()
        {
            return true;
        }

        [HttpGet]
        [Route("SaveServerSettings")]
        public bool SaveIPSettings(string serverAddr, int port, int interval, int timeout, string addressType = null)
        {
            CurrentConfig.RemoteServer.ServerAddress = serverAddr;
            CurrentConfig.RemoteServer.Port = port;
            CurrentConfig.RemoteServer.Interval = interval;
            CurrentConfig.RemoteServer.Timeout = timeout;

            return true;
        }

        [HttpGet]
        [Route("RestoreFactory")]
        public bool RestoreFactory()
        {
            CurrentConfig.UART.Baudrate = 9600;
            CurrentConfig.UART.DataBits = 1;
            CurrentConfig.UART.Parity = Models.UARTConfig.ParityOptions.None;
            CurrentConfig.UART.StopBits = 1;
            CurrentConfig.UART.Parity = Models.UARTConfig.ParityOptions.None;
            return true;
        }
    }
}
