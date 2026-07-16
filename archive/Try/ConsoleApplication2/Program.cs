using log4net;
using log4net.Appender;
using log4net.Config;
using log4net.Core;
using log4net.Layout;
using log4net.Repository;
using log4net.Repository.Hierarchy;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ConsoleApplication2
{
    public class ActivePropertyHelper
    {
        public override string ToString()
        {
            return GC.GetTotalMemory(true).ToString();
        }
    }

    public class Job
    {
        public ILoggerRepository Rep { get; set; }
        public string LoggerName { get; set; }

        public string Tag { get; set; }

    }
    public sealed class DummyLogger : Logger
    {
        // Methods
        internal DummyLogger(string name)
            : base(name)
        {

        }
    }

    class Program
    {
        static Level[] sortedLevels = null;

        public static IAppender CreateRollingFileAppender(string Folder, string applicationId, RollingFileAppender app = null)
        {
            var roller = new RollingFileAppender();
            roller.LockingModel = new log4net.Appender.FileAppender.MinimalLock();
            roller.AppendToFile = true;
            roller.RollingStyle = RollingFileAppender.RollingMode.Composite;
            roller.MaxSizeRollBackups = 14;
            roller.MaximumFileSize = "5KB";
            roller.DatePattern = "yyyyMMdd";
            roller.Layout = new log4net.Layout.PatternLayout();
            roller.File = Path.Combine(Folder, applicationId, "logFile_.log");
            roller.StaticLogFileName = false;
            roller.PreserveLogFileNameExtension = true;

            PatternLayout patternLayout = new PatternLayout();
            patternLayout.ConversionPattern = "%date [%thread] %-5level %logger[%property{MyLocalContextProperty}] [%property{MyContextProperty}] [%property{MyGlobalProperty}] Tag=[%property{tag}] - %message%newline";
            patternLayout.ActivateOptions();
            roller.Layout = patternLayout;
            roller.ActivateOptions();

            return roller;
        }

        static void LoggingMessage(string loggerName, ILog logger, string tag = null)
        {
            for (int i = 0; i < 5; i++)
            {
                using (log4net.ThreadContext.Stacks["MyContextProperty"].Push("logger-" + loggerName))
                {
                    for (int lIndex = 0; lIndex < sortedLevels.Length; lIndex++)
                    {
                        var eData = new LoggingEventData()
                        {
                            Message = "Message - Logger -" + loggerName,
                            Properties = new log4net.Util.PropertiesDictionary(),
                            Level = sortedLevels[lIndex],
                            TimeStamp = DateTime.UtcNow
                        };

                        eData.Properties["tag"] = tag;
                        var e = new LoggingEvent(eData);
                        logger.Logger.Log(e);
                    }
                }
            }
        }

        static void Thread_Logger1(object o)
        {
            var job = o as Job;
            var _logger = job.Rep.GetLogger(job.LoggerName);
            var logger = new LogImpl(_logger);

            LoggingMessage(job.LoggerName, logger, job.Tag);
        }
        static void Main(string[] args)
        {
            Console.WriteLine("Start");

            Solution1();

            Console.WriteLine("Done");
            Console.ReadLine();
        }

        static void Solution1()
        {
            var targetFilesFolder = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetEntryAssembly().Location), "logs");
            var rep_devices = Maba.Connectors.LoggerLib.LoggerManager.GetRepository("Devices",
                null,//Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetEntryAssembly().Location), "Rep_Devices.XML"),
                new Maba.Connectors.LoggerLib.Settings() { TargetFolder = targetFilesFolder });

            rep_devices.Threshold(10000);
            var logger_1 = rep_devices.GetLoggerWrapper("000000");
            logger_1.Debug("Hello-Debug");
            logger_1.Fatal("Hello-Fatal");
            logger_1.Info("Hello-Info");
        }

        static void Solution2()
        {

            #region print levels

            var levels = LogManager.GetRepository().LevelMap.AllLevels;
            sortedLevels = new Level[levels.Count];
            levels.CopyTo(sortedLevels);
            sortedLevels = sortedLevels.OrderBy(l => l.Value).ToArray();
            for (int i = 0; i < sortedLevels.Length; i++)
            {
                Console.WriteLine("{0} {1}={2}", sortedLevels[i], sortedLevels[i].Value, sortedLevels[i].Name);
            }

            #endregion

            #region get devices Repository

            var rep_Devices = LogManager.CreateRepository("Rep_Devices");
            XmlConfigurator.ConfigureAndWatch(rep_Devices,
                new FileInfo(Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetEntryAssembly().Location), rep_Devices.Name + ".XML")));

            Hierarchy hierarchy_Devices = (Hierarchy)rep_Devices;

            hierarchy_Devices.LoggerCreatedEvent += (sender, e) =>
                {
                    e.Logger.AddAppender(CreateRollingFileAppender("App_Data\\Logs1", e.Logger.Name));
                };

            hierarchy_Devices.Threshold = new Level(100000, "");//.Level = Level.Fatal;

            #endregion

            #region get server Repository

            var rep_Server = LogManager.CreateRepository("Rep_Server");
            XmlConfigurator.ConfigureAndWatch(rep_Server,
                new FileInfo(Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetEntryAssembly().Location), rep_Server.Name + ".XML")));

            Hierarchy hierarchy_Server = (Hierarchy)rep_Server;

            hierarchy_Server.Root.Level = Level.Fatal;

            #endregion

            //set Global properties, if needed
            log4net.GlobalContext.Properties["MyGlobalProperty"] = new ActivePropertyHelper();


            #region run devices loggers

            var threads = new List<Task>();

            for (int j = 0; j < 5; j++)
            {
                threads.Clear();

                for (int i = 0; i < 5; i++)
                {
                    var job = new Job()
                    {
                        LoggerName = i.ToString(),
                        Rep = rep_Devices,
                        Tag = "Print_" + j.ToString()
                    };
                    var t = Task.Factory.StartNew(Thread_Logger1, job);
                    threads.Add(t);
                }

                Task.WaitAll(threads.ToArray());
            }

            #endregion

        }
    }
}
