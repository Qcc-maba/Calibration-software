using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace GatewayUI.Models
{
    public class DeviceAllocatedMAC
    {
        public string MAC { get; set; }
    }

    public class RemoteServerConfig
    {
        public string ServerAddress { get; set; }
        public int Port { get; set; }
        public int Timeout { get; set; }
        public int Interval { get; set; }

    }

    public class DeviceInfo
    {
        public string DeviceName { get; set; }
        /// <summary>
        /// Online/Offline
        /// </summary>
        public string SocketStatus { get; set; }
        public int RSSILevel { get; set; }
        public string MAC { get; set; }
        public string IPAddress { get; set; }
        public string FirmwareVersion { get; set; }
        public string SerialStatus { get; set; }

        public string ServerAddress { get; set; }
        public int ServerPort { get; set; }

        public int ServerTotalConnection { get; set; }
    }

    public class IPAddressConfig
    {
        public enum AddressTypeOptions
        {
            AUTO, STATIC
        }
        [JsonConverter(typeof(StringEnumConverter))]
        public AddressTypeOptions AddressType { get; set; }
        public string IPAddress { get; set; }
        public string Subnet { get; set; }
        public string DefaultGateway { get; set; }
        public string DNS { get; set; }
    }

    public class UARTConfig
    {
        public enum FlowControlOptions
        {
            None, Hardware, XonXoff
        }
        public enum ParityOptions
        {
            None, Even, Odd
        }
        /// <summary>
        /// 4800, 9600, 19200,...
        /// </summary>
        public int Baudrate { get; set; }
        public int DataBits { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public ParityOptions Parity { get; set; }
        public int StopBits { get; set; }
        [JsonConverter(typeof(StringEnumConverter))]
        public FlowControlOptions FlowControl { get; set; }
    }

    public class DeviceConfig
    {
        public string DeviceName { get; set; }
        public string MAC { get; set; }

        public UARTConfig UART { get; set; }
        public IPAddressConfig IPConfig { get; set; }
        public RemoteServerConfig RemoteServer { get; set; }
    }
}