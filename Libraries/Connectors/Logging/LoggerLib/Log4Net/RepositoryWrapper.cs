using log4net.Appender;
using log4net.Layout;
using log4net.Repository.Hierarchy;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.LoggerLib.Log4Net
{
    public class RepositoryWrapper : IBaseRepository
    {
        #region CONSTANTS

        public string KEY_RollingLogFileAppender = "RollingLogFileAppender";

        #endregion

        #region properties

        public Hierarchy InternalHierarchy { get; private set; }
        public Settings LoggingSettings { get; set; }
        #endregion

        #region members

        private RollingFileAppender _RollingFileAppender = null;

        #endregion

        #region ctor

        public RepositoryWrapper(Hierarchy hierarchy, Settings settings)
        {
            InternalHierarchy = hierarchy;
            LoggingSettings = settings;

            hierarchy.LoggerCreatedEvent += hierarchy_LoggerCreatedEvent;

            #region look for RollingFileAppender

            for (int i = hierarchy.Root.Appenders.Count - 1; i >= 0; i--)
            {
                if (hierarchy.Root.Appenders[i].Name == KEY_RollingLogFileAppender && hierarchy.Root.Appenders[i] is RollingFileAppender)
                {
                    _RollingFileAppender = hierarchy.Root.Appenders[i] as RollingFileAppender;
                    hierarchy.Root.RemoveAppender(_RollingFileAppender);
                    break;
                }
            }

            #endregion
        }

        #endregion

        #region private methods

        private IAppender CreateRollingFileAppender(string FilesFolder, string name, RollingFileAppender prototypeAppender = null)
        {
            var roller = new RollingFileAppender();
            if (prototypeAppender != null)
            {
                roller.Name = "Roller_" + name;
                roller.LockingModel = Activator.CreateInstance(prototypeAppender.LockingModel.GetType()) as FileAppender.LockingModelBase;
                roller.AppendToFile = prototypeAppender.AppendToFile;
                roller.RollingStyle = prototypeAppender.RollingStyle;
                roller.MaxSizeRollBackups = prototypeAppender.MaxSizeRollBackups;
                roller.MaximumFileSize = prototypeAppender.MaximumFileSize;
                roller.DatePattern = prototypeAppender.DatePattern;
                roller.StaticLogFileName = prototypeAppender.StaticLogFileName;
                roller.PreserveLogFileNameExtension = prototypeAppender.PreserveLogFileNameExtension;

                roller.File = Path.Combine(FilesFolder, name, roller.File ?? "logFile_.log");

                #region Layout

                PatternLayout patternLayout = new PatternLayout();
                patternLayout.ConversionPattern = "%date [%thread] %-5level %logger[%property{MyLocalContextProperty}] [%property{MyContextProperty}] [%property{MyGlobalProperty}] Tag=[%property{tag}] - %message%newline";
                roller.Layout = patternLayout;
                if (prototypeAppender.Layout != null && prototypeAppender.Layout is PatternLayout)
                {
                    patternLayout.ConversionPattern = ((PatternLayout)prototypeAppender.Layout).ConversionPattern;
                }
                patternLayout.ActivateOptions();

                #endregion

                roller.ActivateOptions();
            }
            else
            {
                roller.LockingModel = new log4net.Appender.FileAppender.MinimalLock();
                roller.AppendToFile = true;
                roller.RollingStyle = RollingFileAppender.RollingMode.Composite;
                roller.MaxSizeRollBackups = 14;
                roller.MaximumFileSize = "5KB";
                roller.DatePattern = "yyyyMMdd";
                roller.File = Path.Combine(FilesFolder, name, "logFile_.log");
                roller.StaticLogFileName = false;
                roller.PreserveLogFileNameExtension = true;

                #region Layout

                PatternLayout patternLayout = new PatternLayout();
                patternLayout.ConversionPattern = "%date [%thread] %-5level %logger[%property{MyLocalContextProperty}] [%property{MyContextProperty}] [%property{MyGlobalProperty}] Tag=[%property{tag}] - %message%newline";
                patternLayout.ActivateOptions();
                roller.Layout = patternLayout;

                #endregion

                roller.ActivateOptions();
            }

            return roller;
        }

        void hierarchy_LoggerCreatedEvent(object sender, LoggerCreationEventArgs e)
        {
            if (LoggingSettings != null && LoggingSettings.AddFileLogger)
            {
                var filesFolder = this.LoggingSettings == null ? "" : this.LoggingSettings.TargetFolder;
                e.Logger.AddAppender(CreateRollingFileAppender(filesFolder, e.Logger.Name, _RollingFileAppender));
            }
        }

        #endregion

        #region IBaseRepository members

        public void Shutdown()
        {
            InternalHierarchy.Shutdown();
        }

        public void Threshold(int level, string name = "")
        {
            InternalHierarchy.Threshold = new log4net.Core.Level(level, name ?? "");
        }

        public IBaseLogger GetLoggerWrapper(string name)
        {
            var l = InternalHierarchy.GetLogger(name);

            return new LoggerWrapper(l);
        }

        #endregion



    }
}
