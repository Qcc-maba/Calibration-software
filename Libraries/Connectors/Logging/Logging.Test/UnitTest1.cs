using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.IO;

namespace Maba.Connectors.LoggerLib
{
    [TestClass]
    public class UnitTest1
    {
        [TestMethod]
        public void TestMethod1()
        {
            //init vars
            var repositoryName = "myRep";
            var folder = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            string configName = Path.Combine(folder, "log4netConfigExample.XML");


            var logsFolder = Path.Combine(folder, "Logs");
            var st = new LoggerLib.Settings()
            {
                AddFileLogger = true,
                TargetFolder = logsFolder
            };
            //recreate the logs folder
            if (Directory.Exists(logsFolder))
            {
                try
                {
                    Directory.Delete(logsFolder, true);
                }
                catch { }
            }
            Directory.CreateDirectory(logsFolder);

            //create repository
            var rep = LoggerLib.LoggerManager.GetRepository(repositoryName, configName, st);
            Assert.IsNotNull(rep);
            rep.Threshold(10000);

            //creat wrapper
            var wrapperName = "Shoshi";
            var wr = rep.GetLoggerWrapper(wrapperName);

            Assert.IsNotNull(wr);

            //test
            var debugMessage = "Hello, Debug Message";
            var debugE = new Exception("Exception1");
            wr.Info(debugMessage);
            wr.Debug(debugMessage, debugE);

            //test wrapper folder
            var wrapperFolders = Directory.GetDirectories(logsFolder);
            Assert.AreEqual(1, wrapperFolders.Length);
            Assert.AreEqual(wrapperName, Path.GetFileName(wrapperFolders[0]));

            var files = Directory.GetFiles(wrapperFolders[0]);
            Assert.AreNotEqual(0, files.Length);
        }
    }
}
