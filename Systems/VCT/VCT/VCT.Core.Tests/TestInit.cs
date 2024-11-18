using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Tests
{
    public class TestInit
    {
        #region Members

        public Settings.VCTSettings Settings = null;

        public int MaxRemoteDevices { get; private set; }
        public int VCT_Port { get; private set; }

        //public string ServerAddress = "192.168.167.222";
        //public string ServerAddress = "localhost";

        //public string ServerAddress = "";
        public string ServerAddress = "rnd1.glc-service.com";
        //public Clients.Demo.Bus _bus { get; set; }
        public ushort RecordSize { get; private set; }
        public int MemorySize { get; set; }

        protected ServerCore Server { get; set; }

        #endregion

        #region ctors(s)

        public TestInit(int port)
        {
            VCT_Port = port;
            MaxRemoteDevices = 1;
            RecordSize = 31;
            MemorySize = 1000;
        }

        #endregion

        #region protected / abstract methods
        protected virtual void CreateServer()
        {
            Settings = Core.Settings.VCTSettings.CreateDefaultSettings();

            Settings.Tunnels[0].Address = ServerAddress;
            Settings.Tunnels[0].Ports = new int[] { VCT_Port };

            Server = new ServerCore();
            Server.MainEventsBus.DeviceConnnection += MainEventsBus_DeviceConnnection;
            Server.Start(Settings);

            Server.MainEventsBus.AutoHandleNewDevices = true;
        }

        private void MainEventsBus_DeviceConnnection(object o, Events.DeviceConnectionEventArgs e)
        {

        }

        protected string BuildSN(int i)
        {
            return i.ToString().PadLeft(16, '0');
        }

        #endregion

        #region Public Methods

        [TestInitialize]
        public void Start()
        {
            CreateServer();

            //_bus = new Clients.Demo.Bus();
            //_bus.AddClients(MaxRemoteDevices, i =>
            //{
            //    return new Clients.Demo.Client(ServerAddress, VCT_Port, i.ToString().PadLeft(16, '0'))
            //    {
            //        ConnectInterval = TimeSpan.FromMinutes(10),
            //        ClockOffset = TimeSpan.FromSeconds(i),
            //        Datalogger_Memory = BuildDataLoggerMemeory(MemorySize),
            //        Datalogger_RecordSize = RecordSize
            //    };
            //});

            //_bus.Start();

            //let all device to JIT all dlls first.. (Eliran excuse)
            System.Threading.Thread.Sleep(500);
        }

        #endregion

        #region Private Methods
        private byte[] BuildDataLoggerMemeory(int memSize)
        {
            var b = new byte[memSize];

            int index = 0;
            while (index + RecordSize <= b.Length)
            {
                for (int i = index; i < index + RecordSize; i++)
                {
                    b[i] = (byte)((i % 10) * 10);
                }

                index += RecordSize;
            }

            return b;
        }

        #endregion
    }
}
