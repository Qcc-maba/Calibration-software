using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.LoggerLib
{
    public class Settings
    {
        public string TargetFolder { get; set; }
        public bool AddFileLogger { get; set; }

        public Settings()
        {
            AddFileLogger = true;
        }
    }
}
