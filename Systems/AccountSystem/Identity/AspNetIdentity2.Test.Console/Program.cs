using Maba.AccountSystem.AspNetIdentity.Identity2.Test;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections;
using System.Data;
using System.Data.Common;

namespace testConsole
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.ForegroundColor = ConsoleColor.White;
            Console.BackgroundColor = ConsoleColor.Black;
            //statics
            int Counter_PASS = 0;
            int Counter_FAIL = 0;

            var context = new MyTestContext();

            var testType = typeof(Identity2UserManagerTests);
            var methods = testType.GetMethods(System.Reflection.BindingFlags.Public
                | System.Reflection.BindingFlags.Instance
                | System.Reflection.BindingFlags.InvokeMethod);

            foreach (var m in methods.OrderBy(r => r.Name))
            {
                //general action
                 //System.Data.SqlClient.SqlConnection.ClearAllPools();

                //init test file
                var testerFile = new Identity2UserManagerTests()
                {
                    TestContext = context
                };

               // System.Threading.Thread.Sleep(500);
                //ignore properties
                if (m.Name.StartsWith("set") || m.Name.StartsWith("get"))
                {
                    continue;
                }

                if (m.CustomAttributes.Any(a => a.AttributeType == typeof(TestMethodAttribute)))
                {
                    try
                    {
                        context.SetTestName(m.Name);
                        testerFile.Init();

                        Console.WriteLine("Method :: {0}", m.Name);
                        m.Invoke(testerFile, new object[0]);

                        testerFile.cleanup();

                        Counter_PASS++;
                    }
                    catch
                    {
                        Counter_FAIL++;
                    }
                }
            }

            if (Counter_FAIL > 0)
            {
                Console.ForegroundColor = ConsoleColor.White;
                Console.BackgroundColor = ConsoleColor.Red;

                Console.WriteLine("Results:: PASS:{0}, FAIL:{1}", Counter_PASS, Counter_FAIL);
                Console.ReadLine();
            }
            else
            {
                Console.WriteLine("Results:: PASS:{0}, FAIL:{1}", Counter_PASS, Counter_FAIL);
            }

            // Console.ReadLine();
            System.Threading.Thread.Sleep(500);
        }
    }


    class MyTestContext : TestContext
    {
        private string _TestName = null;
        public void SetTestName(string name)
        {
            _TestName = name;

        }
        public override string TestName
        {
            get
            {
                return _TestName;
            }
        }

        public override DbConnection DataConnection
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public override DataRow DataRow
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public override IDictionary Properties
        {
            get
            {
                throw new NotImplementedException();
            }
        }

        public override void AddResultFile(string fileName)
        {
        }

        public override void BeginTimer(string timerName)
        {
        }

        public override void EndTimer(string timerName)
        {
        }

        public override void WriteLine(string format, params object[] args)
        {
            Console.WriteLine(format, args);
        }
    }
}
