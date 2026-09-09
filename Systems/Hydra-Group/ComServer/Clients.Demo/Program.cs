
using System;

namespace Maba.VCT.Clients.Demo.Hydra2
{
    class Program
    {
        #region Main

        [MTAThread]
        static void Main(string[] args)
        {
            int waitSeconds = 3;
            Console.Write("Wait {0} seconds to Start....", waitSeconds);
            System.Threading.Thread.Sleep(waitSeconds * 1000);

            Console.WriteLine(" - Started!");

            string Addr ="rnd1.glc-service.com";
            int port = 50100;
            int NumberOfCliets = 1;

            var b = new Clients.Demo.Bus();
            b.AddClients(NumberOfCliets, i =>
                {
                    return new Client_Hydra2(Addr, port, i.ToString().PadLeft(16, '1'))
                    {
                        ConnectInterval = TimeSpan.FromSeconds(10),
                        State = Client.States.KeepConntected,
                        SendIdentificationPacketUponConnection = true
                    };
                });

            b.Start();

            Console.WriteLine("Running...");

            while (true)
            {

            }
        }

        #endregion
    }
}
