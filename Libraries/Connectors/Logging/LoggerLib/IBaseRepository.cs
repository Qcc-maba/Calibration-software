using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.LoggerLib
{
    public interface IBaseRepository
    {
        IBaseLogger GetLoggerWrapper(string name);
        void Shutdown();
        void Threshold(int level, string name = null);

    }
}
