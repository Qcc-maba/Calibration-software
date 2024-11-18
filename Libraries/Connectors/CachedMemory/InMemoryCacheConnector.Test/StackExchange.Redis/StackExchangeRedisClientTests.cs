using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Connectors.InMemoryCache.StackExchange.Redis;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.InMemoryCache.StackExchange.Redis.Tests
{
    [TestClass()]
    public class StackExchangeRedisClientTests
    {
        private StackExchangeRedisClient CreateConnector()
        {
            var servers = new string[]
            {
                //"server1.Maba-smart.com:6001,",
                //"server1.Maba-smart.com:6002,",
                //"server1.Maba-smart.com:7001,",
                "server1.Maba-smart.com:7002"
            };

            var connector = new StackExchange.Redis.StackExchangeRedisClient(string.Concat(servers));

            return connector;
        }

        private T Test<T>(Task<T> t)
        {
            Assert.IsTrue(t.Wait(1000));

            return t.Result;
        }


        [TestMethod()]
        public void Cluster_Test()
        {
            var connector = this.CreateConnector();

            var keys = new string[]
            {
                //2650
                "shmulik",
                //12182
                "foo"
            };

            foreach (var k in keys)
            {
                var keyslot = connector.CalcHashSlot(k);
                var value = "1234";

                Assert.IsTrue(Test(connector.SetKeyAsync(k, value)));

                var value_back = Test(connector.GetKeyAsync(k));
                Assert.AreEqual(value, value_back);
            }
        }












        [TestMethod()]
        public void GetKeyAsyncTest()
        {
            var connector = this.CreateConnector();

            string key = $"myKey_{Guid.NewGuid()}";
            string value = Guid.NewGuid().ToString();

            //test before setting
            var value_test1 = Test(connector.GetKeyAsync(key));
            Assert.IsNull(value_test1);

            Test(connector.SetKeyAsync(key, value));

            var value_test = Test(connector.GetKeyAsync(key));
            Assert.AreEqual(value, value_test);
        }

        [TestMethod()]
        public void SetKeyAsyncTest()
        {
            //covered by GetKeyAsyncTest
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void GetHashKeyAsyncTest()
        {
            var connector = this.CreateConnector();

            for (int i = 0; i < 10; i++)
            {
                string key = GetKey();

                for (int j = 0; j < 10; j++)
                {
                    string hashKey = GetKey();
                    string value = GetValue();

                    Assert.IsTrue(Test(connector.SetHashKeyAsync(key, hashKey, value)));

                    //test it back
                    var value_back = Test(connector.GetHashKeyAsync(key, hashKey));
                    Assert.AreEqual(value, value_back);
                }
            }
        }


        [TestMethod()]
        public void GetHashAllKeysAsyncTest()
        {
            var connector = this.CreateConnector();

            //make values
            var hashKeys = new KeyValuePair<string, string>[10];
            for (int i = 0; i < hashKeys.Length; i++)
            {
                hashKeys[i] = new KeyValuePair<string, string>($"key_{i}", $"val_{i}");
            }

            //add to memory
            string key = GetKey();

            for (int i = 0; i < hashKeys.Length; i++)
            {
                Assert.IsTrue(Test(connector.SetHashKeyAsync(key, hashKeys[i].Key, hashKeys[i].Value)));

                //test it back
                var value_back = Test(connector.GetHashKeyAsync(key, hashKeys[i].Key));
                Assert.AreEqual(hashKeys[i].Value, value_back);
            }

            //test all hash
            var hash_back = Test(connector.GetHashAllKeysAsync(key));
            Assert.IsNotNull(hashKeys);
            Assert.AreEqual(hashKeys.Length, hash_back.Length);

            foreach (var k in hash_back)
            {
                Assert.AreEqual(1, hashKeys.Count(kk => kk.Key == k.Key && kk.Value == k.Value));
            }
        }

        [TestMethod()]
        public void GetHashAllKeysAsync2Test()
        {
            var connector = this.CreateConnector();

            //make values
            var hashKeys = new KeyValuePair<string, string>[10];
            for (int i = 0; i < hashKeys.Length; i++)
            {
                hashKeys[i] = new KeyValuePair<string, string>($"key_{i}", $"val_{i}");
            }

            //add to memory
            string key = GetKey();

            Assert.IsTrue(Test(connector.SetHashKeysAsync(key, hashKeys)));

            //test all hash
            var hash_back = Test(connector.GetHashAllKeysAsync(key));
            Assert.IsNotNull(hashKeys);
            Assert.AreEqual(hashKeys.Length, hash_back.Length);

            foreach (var k in hash_back)
            {
                Assert.AreEqual(1, hashKeys.Count(kk => kk.Key == k.Key && kk.Value == k.Value));
            }
        }

        private static string GetKey()
        {
            return $"myKey_{Guid.NewGuid().ToString().Substring(0, 5)}";
        }

        private static string GetValue()
        {
            return $"myValue_{Guid.NewGuid().ToString().Substring(0, 5)}";
        }

        [TestMethod()]
        public void SetHashKeyAsyncTest()
        {

        }

        [TestMethod()]
        public void PrepareAndLoadScriptTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void ExecuteLuaTest()
        {
            Assert.Fail();
        }
    }
}