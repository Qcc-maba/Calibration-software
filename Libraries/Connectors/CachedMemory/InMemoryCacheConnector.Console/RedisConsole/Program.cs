using Maba.Connectors.InMemoryCache.StackExchange.Redis;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RedisConsole
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Redis Demo");
            Console.WriteLine("-".PadLeft(60, '-'));

            Console.WriteLine("Enter Redis Endpoint>");
            var endpoint1 = Console.ReadLine();
            Console.WriteLine();

            Console.WriteLine("Connecting....");

            var client = new StackExchangeRedisClient(endpoint1);
            Console.WriteLine("Connected");

            while (true)
            {
                bool failed = false;
                Console.WriteLine("Enter key to set (Key Value)>");
                var key_value = Console.ReadLine();
                var k = key_value.Split(' ');

                if (k != null | k.Length == 2)
                {
                    Console.WriteLine("Setting key in redis (slot={0}, key={1}...", k[0], client.CalcHashSlot(k[0]));

                    try
                    {
                        var setTask = client.SetKeyAsync(k[0], k[1]);
                        setTask.Wait();
                    }
                    catch (System.AggregateException e)
                    {
                        failed = true;
                        Console.WriteLine("Exception:> {0}", e.InnerException.Message);
                    }
                    catch (Exception e)
                    {
                        failed = true;
                        Console.WriteLine("Exception:> {0}", e.Message);
                    }

                    if (failed)
                        continue;
                    Console.WriteLine("reading from redis..");
                    try
                    {
                        var getTask = client.GetKeyAsync(k[0]);
                        getTask.Wait();

                        Console.WriteLine("Got value - >{0}", getTask.Result);
                    }
                    catch (System.AggregateException e)
                    {
                        failed = true;
                        Console.WriteLine("Exception:> {0}", e.InnerException.Message);
                    }
                    catch (Exception e)
                    {
                        failed = true;
                        Console.WriteLine("Exception:> {0}", e.Message);
                    }
                }
                else
                {
                    Console.WriteLine("wrong format");
                }

            }

            Console.WriteLine("Done. Press Enter to exit..");

            Console.ReadLine();
        }
    }
}
