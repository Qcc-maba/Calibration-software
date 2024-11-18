using log4net;
using log4net.Config;
using log4net.Repository.Hierarchy;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.LoggerLib
{
    public class LoggerManager
    {
        public static IBaseRepository GetRepository(string name, string configFileName, Settings settings)
        {
            var rep = LogManager.CreateRepository(name);
            if (!String.IsNullOrEmpty(configFileName))
            {
                XmlConfigurator.ConfigureAndWatch(rep, new FileInfo(configFileName));
            }
            var h = (Hierarchy)rep;

            BasicConfigurator.Configure();
            return new Log4Net.RepositoryWrapper(h, settings);
        }


    }
}
