using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class LogsRequest : DeviceBaseRequest
    {
        #region Enum

        public enum LogCommands : int
        {
            StopScan = 0,
            StartScan = 1,
            ClearLogs = 2,
            LogCount = 3,
            GetLogs = 4
        }
        #endregion

        #region Members

        public LogCommands LogCommand { get; private set; }
        public int IntervalBetweenScans { get; private set; }
        #endregion

        #region ctors(s)

        public LogsRequest(LogCommands logCommands)
            : base()
        {
            LogCommand = logCommands;
        }
        public LogsRequest(LogCommands logCommands, int intervalBetweenScans) : this(logCommands)
        {
            this.IntervalBetweenScans = intervalBetweenScans;
        }
        #endregion

    }
}
