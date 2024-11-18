using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.Connectors.InMemoryCache.Test
{
    [TestClass]
    public class SimpleGetSet_UnitTest
    {
        [TestMethod]
        public void TestMethod1()
        {
            var connector = new StackExchange.Redis.StackExchangeRedisClient();
            //var hash = connector.LoadScript("owner1", 1234);

            var script = " if redis.call('exists', KEYS[1]) == 1 then "
                        + "     if redis.call('get', KEYS[1]) == ARGV[1] then "
                        + "         redis.call('set', KEYS[1], ARGV[1])"
                        + "         return 'V1' "
                        + "     else "
                        + "         return 'X1'"
                        + "     end"
                        + " else "
                        + "     redis.call('set', KEYS[1], ARGV[1]) "
                        + "     return 'V2' "
                        + "end;";

            //script = "return redis.call('exists', KEYS[1])";
            var hash = connector.PrepareAndLoadScript(script);
            var result = connector.ExecuteLua<string, string>(hash, new string[] { "eitan" }, new string[] { "33" });
        }


        [TestMethod]
        public void TestMethod2()
        {
            var connector = new StackExchange.Redis.StackExchangeRedisClient();


            for (int i = 0; i < 10000; i++)
            {
                Assert.IsTrue(connector.SetKeyAsync("a", "1").Wait(1000));
                Assert.IsTrue(connector.GetKeyAsync("a").Wait(1000));

            }
        }
    }
}
