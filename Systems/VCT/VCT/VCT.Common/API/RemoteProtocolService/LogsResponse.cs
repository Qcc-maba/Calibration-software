using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq.Expressions;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class LogsResponse : BaseResponse
    {
        #region Members

        public LogsRequest.LogCommands LogCommand { get; private set; }
        public DateTime LogDate { get; private set; }
        public int Alarm { get; private set; }
        public int DigitalIOLineState { get; private set; }
        public string Totalizer { get; private set; }
        public List<double> Measurements = new List<double>();
        public int LogCount { get; private set; }
        #endregion

        #region ctor

        public LogsResponse(bool result, LogsRequest.LogCommands logCommand) : base(result)
        {
            LogCommand = logCommand;
        }


        public LogsResponse(double temperature, double humudity)
        {
            Measurements = new List<double>() { temperature, humudity };
        }
        #endregion

        #region Private Methods

        //public void ParseLogPacket(HardwarePacket p, bool isDataPoint)
        //{

        //    string[] results = p.Response.Replace("\r\n", "").Replace("=>", "").Split(',');
        //    Mesurements = new List<double>(); ;
        //    if (!isDataPoint)
        //    {
        //        var hours = int.Parse(results[0]);
        //        var minutes = int.Parse(results[1]);
        //        var seconds = int.Parse(results[2]);
        //        var month = int.Parse(results[3]);
        //        var day = int.Parse(results[4]);
        //        var year = int.Parse(results[5]) + 2000;
        //        LogDate = new DateTime(year, month, day, hours, minutes, seconds);
        //        for (int i = 6; i < results.Length - 3; i++)
        //        {
        //            Mesurements.Add(double.Parse(results[i]));
        //        }
        //        Alarm = int.Parse(results[results.Length - 3]);
        //        DigitalIOLineState = int.Parse(results[results.Length - 2]);
        //        Totalizer = results[results.Length - 1];
        //    }
        //    else
        //    {
        //        //LogCount = int.Parse(results[0]);
        //        for (int i = 0; i < results.Length; i++)
        //        {
        //            Mesurements.Add(double.Parse(results[i]));
        //        }
        //    }
        //}

        public void ParseLogResponse(HardwarePacket commandPacket, HardwarePacket result, LogsRequest.LogCommands logCommand)
        {
            switch (logCommand)
            {
                case LogsRequest.LogCommands.StopScan:
                    break;
                case LogsRequest.LogCommands.StartScan:
                    break;
                case LogsRequest.LogCommands.ClearLogs:
                    break;
                case LogsRequest.LogCommands.LogCount:
                    string numOfLogs = result.Response.Replace("\r", "").Replace("\n", "").Replace("=>", "");
                    this.LogCount = int.Parse(numOfLogs);
                    HasResponse = true;
                    break;
                case LogsRequest.LogCommands.GetLogs:
                    if (commandPacket.Command.Contains("SCAN:DATA:Last?"))
                    {
                        var t = result.Response.Split(';');
                        foreach (var item in t)
                        {
                            var t1 = item.Split(',');
                            if (t1.Length >= 5)
                            {
                                Measurements.Add(double.Parse(t1[3]));
                                HasResponse = true;
                            }
                        }
                    }
                    else if (commandPacket.Command.Contains("MEAS"))
                    {
                        double res;
                        var x = result.Response.Replace("\n", "");
                        var t = double.TryParse(x, out res);

                        Measurements.Add(res);
                        HasResponse = true;
                    }
                    else if (commandPacket.Command == "06"|| commandPacket.Command =="08")
                    {
                        Measurements.Add(result.FloatData);
                        HasResponse = true;
                    }
                    else if (commandPacket.Command.Contains("GET DATA"))
                    {
                        //string[] results = result.Response.Replace("\r\n", "").Replace("=>", "").Split(',');
                        var res = result.Response.Split(new[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries);
                        if (res.Length > 3)
                        {
                            foreach (var item in res)
                            {
                                if (item.Contains("Ohm"))
                                {
                                    Measurements.Add(double.Parse(item.Substring(5, item.Length - 9)));
                                    HasResponse = true;
                                }
                            }
                        }
                    }
                    else if (commandPacket.Command.Contains("DATA"))
                    {
                        string[] results = result.Response.Replace("\r\n", "").Replace("=>", "").Split(',');
                        LogCount = int.Parse(results[0]);
                        HasResponse = true;
                    }
                    else if (commandPacket.Command.Contains("READ"))
                    {
                        var temp = result.Response.Replace("\r\n", "").Replace("=>", "").Split(',');
                        foreach (var item in temp)
                        {
                            Measurements.Add(double.Parse(item));
                        }
                        HasResponse = true;
                    }
                    else
                    {
                        string[] results = result.Response.Replace("\r\n", "").Replace("=>", "").Split(',');
                        var hours = int.Parse(results[0]);
                        var minutes = int.Parse(results[1]);
                        var seconds = int.Parse(results[2]);
                        var month = int.Parse(results[3]);
                        var day = int.Parse(results[4]);
                        var year = int.Parse(results[5]) + 2000;
                        LogDate = new DateTime(year, month, day, hours, minutes, seconds);
                        for (int i = 6; i < results.Length - 3; i++)
                        {
                            Measurements.Add(double.Parse(results[i]));
                        }
                        DigitalIOLineState = int.Parse(results[results.Length - 2]);
                        Totalizer = results[results.Length - 1];
                    }

                    break;
                default:
                    break;
            }
        }

        #endregion
    }
}
