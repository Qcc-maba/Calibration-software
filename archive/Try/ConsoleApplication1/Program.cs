using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.Threading;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using StackExchange.Redis;
using XXX.ClassLibraryTry;

namespace ConsoleApplication1
{

    class Program
    {
        static void Main(string[] args)
        {
            var xx = System.Math.Sqrt(90);
            var rand = new Random();

            decimal r = 956.345m;

            var str = $"{r:2,1}-{r:3}";
            Console.WriteLine(str);




            //var typeName = typeof(MyClass);

            //System.IO.Path.GetFileNameWithoutExtension(typeName.Assembly.ManifestModule.Name)
            //((System.Reflection.RuntimeModule)((System.Reflection.RuntimeAssembly)((System.RuntimeType)typeName).Assembly).ManifestModule).Name


            var c = Activator.CreateInstance("ClassLibraryTry", "XXX.ClassLibraryTry.MyClass");
            var o = c.Unwrap() as XXX.ClassLibraryTry.IClass;

            return;
            //var ff = string.Concat((char)('A' + rand.Next(0, 'Z' - 'A')), (byte)'A' + rand.Next(0, 'Z' - 'A'));
            //var dd = ((char)((byte)'A' + rand.Next(0, 'Z' - 'A'))).ToString();
            //int AsyncOpsQty = 10000;
            //if (args.Length == 1)
            //{
            //    int tmp;
            //    if (int.TryParse(args[0], out tmp))
            //        AsyncOpsQty = tmp;
            //}
            //MassiveBulkOpsAsync(AsyncOpsQty, true, true);
            //MassiveBulkOpsAsync(AsyncOpsQty, true, false);
            //MassiveBulkOpsAsync(AsyncOpsQty, false, true);
            //MassiveBulkOpsAsync(AsyncOpsQty, false, false);
        }
        static void MassiveBulkOpsAsync(int AsyncOpsQty, bool preserveOrder, bool withContinuation)
        {
            using (var muxer = ConnectionMultiplexer.Connect("localhost,resolvedns=1"))
            {


                muxer.PreserveAsyncOrder = preserveOrder;
                RedisKey key = "MBOA";
                var conn = muxer.GetDatabase();
                muxer.Wait(conn.PingAsync());


                //conn.HashGetAll(null)[0].Value.
#if DNXCORE50
                int number = 0;
#endif
                Action<Task> nonTrivial = delegate
                {
#if !DNXCORE50
                    Thread.SpinWait(5);
#else
                    for (int i = 0; i < 50; i++)
                    {
                        number++;
                    }
#endif
                };
                var watch = Stopwatch.StartNew();
                for (int i = 0; i <= AsyncOpsQty; i++)
                {
                    var t = conn.StringSetAsync(key, i);
                    if (withContinuation) t.ContinueWith(nonTrivial);
                }
                int val = (int)muxer.Wait(conn.StringGetAsync(key));
                watch.Stop();

                Console.WriteLine("After {0}: {1}", AsyncOpsQty, val);
                Console.WriteLine("({3}, {4})\r\n{2}: Time for {0} ops: {1}ms; ops/s: {5}", AsyncOpsQty, watch.ElapsedMilliseconds, Me(),
                    withContinuation ? "with continuation" : "no continuation", preserveOrder ? "preserve order" : "any order",
                    AsyncOpsQty / watch.Elapsed.TotalSeconds);
            }
        }
        protected static string Me([CallerMemberName] string caller = null)
        {
            return caller;
        }
    }
}
