using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class LogsResponse : DeviceBaseResponse
    {
        #region Members

        public LogsRequest.LogCommands LogCommand { get; private set; }
        public DateTime LogDate { get; private set; }
        public int Alarm { get; private set; }
        public int DigitalIOLineState { get; private set; }
        public string Totalizer { get; private set; }
        public List<double> Mesurements { get; private set; }
        public int LogCount { get; private set; }
        #endregion

        #region ctor
        public LogsResponse(Packet p, LogsRequest.LogCommands logcommand, bool extend) : this(p.OK, logcommand)
        {
            ParseLogPacket(p, extend);
        }

        public LogsResponse(bool result, LogsRequest.LogCommands logcommand, int logCount) : this(result, logcommand)
        {
            this.LogCount = logCount;
        }

        public LogsResponse(bool result, LogsRequest.LogCommands logCommand) : this(result)
        {
            LogCommand = logCommand;
        }

        public LogsResponse(bool result)
        {
            Result = result;
        }
        #endregion

        #region Private Methods

        public void ParseLogPacket(Packet p, bool extend)
        {

            string[] results = p.Response.Replace("\r\n", "").Replace("=>", "").Split(',');
            Mesurements = new List<double>(); ;
            if (extend)
            {
                var hours = int.Parse(results[0]);
                var minutes = int.Parse(results[1]);
                var seconds = int.Parse(results[2]);
                var month = int.Parse(results[3]);
                var day = int.Parse(results[4]);
                var year = int.Parse(results[5]) + 2000;
                LogDate = new DateTime(year, month, day, hours, minutes, seconds);
                for (int i = 6; i < results.Length - 3; i++)
                {
                    Mesurements.Add(double.Parse(results[i]));
                }
                Alarm = int.Parse(results[results.Length - 3]);
                DigitalIOLineState = int.Parse(results[results.Length - 2]);
                Totalizer = results[results.Length - 1];
            }
            else
            {
                for (int i = 0; i < results.Length; i++)
                {
                    Mesurements.Add(double.Parse(results[i]));
                }
            }
        }

        #endregion
    }
}
