using log4net.Core;
using log4net.Repository.Hierarchy;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.LoggerLib.Log4Net
{
    public class LoggerWrapper : LogImpl, IBaseLogger
    {
        public LoggerWrapper(ILogger l)
            : base(l)
        {

        }
    }
}
