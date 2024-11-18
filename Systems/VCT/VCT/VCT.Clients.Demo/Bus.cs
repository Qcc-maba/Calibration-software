using System;
using System.Collections.Generic;
using System.Timers;

namespace Maba.VCT.Clients.Demo
{
    public class Bus
    {
        #region members

        public bool IsRunning { get; private set; }
        private Timer timer = null;
        private List<Client> Clients = new List<Client>();

        #endregion

        #region public methods

        public void Start()
        {
            IsRunning = true;

            timer = new Timer();
            timer.AutoReset = false;
            timer.Interval = 50;
            timer.Elapsed += timer_Elapsed;
            timer.Start();
        }

        public bool AddClients(int amount, Func<int, Client> fakeClient_Generator)
        {
            if (IsRunning)
                return false;

            for (int i = 0; i < amount; i++)
            {
                Clients.Add(fakeClient_Generator(i));
            }

            return true;
        }

        public IEnumerable<Client> EnumerateClients()
        {
            return Clients.AsReadOnly();
        }

        #endregion

        #region timer methods

        void timer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {
            foreach (var client in Clients)
            {
                client.Timer();
            }

            timer.Start();
        }

        #endregion
    }
}
