using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.Online.ClientLibrary;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Online.ClientLibrary.Tests
{
    [TestClass()]
    public class ClientTests
    {
        private Client _CreateClient()
        {
            var settings = new ClientSettings()
            {
                OnlineServerUrl = "http://online.cheers2.net:3003",
                UseSSL = false
            };

            //settings = new ClientSettings()
            //{
            //    OnlineServerUrl = "https://online.cheers2.net:8443",
            //    UseSSL = true
            //};
            var client = new Client(settings);

            return client;
        }

        private T Test<T>(Task<T> t)
        {
            Assert.IsTrue(t.Wait(20000));

            return t.Result;
        }

        [TestMethod()]
        public void SetUnitStatusTest()
        {
            var client = _CreateClient();

            string sn = $"sn_1234_{Guid.NewGuid().ToString().Substring(0, 4)}";
            sn = "XCIRwxyz00000019";

            for (int i = 0; i < 6; i++)
            {
                var status = new Models.DeviceStatus()
                {
                    Connection = i % 2 == 0,
                    IsFailure = i % 3 == 0,
                    IsFertilizing = i % 2 == 0,
                    IsIrrigating = i % 2 == 0,
                    Status = i % 2 == 0
                };

                //set to redis
                Assert.IsTrue(Test(client.SetUnitStatusAsync(sn, status)));

                //get it back
               /* var status_back = Test<Models.DeviceStatus>(client.GetUnitStatusAsync(sn));
                Assert.IsNotNull(status_back);

                Assert.AreEqual(status.Connection, status_back.Connection);
                Assert.AreEqual(status.IsFailure, status_back.IsFailure);
                Assert.AreEqual(status.IsFertilizing, status_back.IsFertilizing);
                Assert.AreEqual(status.IsIrrigating, status_back.IsIrrigating);
                Assert.AreEqual(status.Status, status_back.Status);*/
            }
        }

        [TestMethod()]
        public void GetUnitStatusTest()
        {
            Assert.Fail();
        }
    }
}