using System;
using System.Diagnostics;
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

        /// <summary>
        /// The reply exactly as the device sent it. Instruments whose format none of the numeric
        /// branches below can read - the Siglent generator answers "C1:BSWV WVTP,SINE,FRQ,1000HZ,..."
        /// with units glued onto the numbers - are parsed by their own BL from this text.
        /// </summary>
        public string RawText { get; private set; }
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

        /// <summary>
        /// Commands whose reply is handled by the device's own BL from <see cref="RawText"/> rather
        /// than by the numeric branches below.
        /// <list type="bullet">
        /// <item>Siglent SDG6052X (":BSWV", ":OUTP") answers key/value pairs with units glued onto
        /// the numbers.</item>
        /// <item>PRODIGIT 3111 ("LOAD?", "MODE?", "VER?", "ERR?") answers a bare token that is not a
        /// measurement.</item>
        /// </list>
        /// Without this, both would fall through to the Hydra date/time parser and log a warning on
        /// every single read, and the BL would see no reply at all.
        /// </summary>
        private static bool IsRawTextCommand(string command)
        {
            if (string.IsNullOrEmpty(command)) return false;

            if (command.IndexOf(":BSWV", StringComparison.OrdinalIgnoreCase) >= 0
             || command.IndexOf(":OUTP", StringComparison.OrdinalIgnoreCase) >= 0)
                return true;

            var trimmed = command.Trim();
            return trimmed.Equals("LOAD?", StringComparison.OrdinalIgnoreCase)
                || trimmed.Equals("MODE?", StringComparison.OrdinalIgnoreCase)
                || trimmed.Equals("VER?", StringComparison.OrdinalIgnoreCase)
                || trimmed.Equals("ERR?", StringComparison.OrdinalIgnoreCase);
        }

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
                    RawText = result != null ? result.Response : null;

                    if (IsRawTextCommand(commandPacket.Command))
                    {
                        // Siglent shorthand (SDG6052X). The values carry unit suffixes ("FRQ,1000HZ"),
                        // so nothing numeric is extracted here - Sdg6052xReplies parses RawText. Without
                        // this branch the reply would fall through to the Hydra date/time parser below
                        // and log a warning on every single read.
                        HasResponse = !string.IsNullOrEmpty(RawText);
                    }
                    else if (commandPacket.Command.Contains("SCAN:DATA:Last?"))
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
                        // SCPI :MEASure? reply - a single NR3 value, e.g. "+1.24000E+00\n" (Keysight
                        // EDUX1002A). Parsed invariant so a he-IL locale cannot reinterpret the decimal
                        // separator, and recorded only on success: a reply that fails to parse must not
                        // reach the app as a reading of 0.
                        var x = result.Response.Replace("\r", "").Replace("\n", "").Replace("=>", "").Trim();
                        if (double.TryParse(x, System.Globalization.NumberStyles.Float,
                                            System.Globalization.CultureInfo.InvariantCulture, out double measured))
                        {
                            Measurements.Add(measured);
                            HasResponse = true;
                        }
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
                    else if (commandPacket.Command.IndexOf("SOUR:", StringComparison.OrdinalIgnoreCase) >= 0
                          || commandPacket.Command.IndexOf("MEASure", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        // Datron/Wavetek 9100 SCPI value query (e.g. SOUR:VOLTage? -> "1.000000E+00"): a single
                        // scientific-notation value, EOI-terminated (GpibCom normalises the reply to end with CRLF).
                        // None of the Hydra branches above match, and the date/time fallback below would throw on it.
                        var x = result.Response.Replace("\r", "").Replace("\n", "").Replace("=>", "").Trim();
                        if (double.TryParse(x, System.Globalization.NumberStyles.Float,
                                            System.Globalization.CultureInfo.InvariantCulture, out double scpiValue))
                        {
                            Measurements.Add(scpiValue);
                            HasResponse = true;
                        }
                    }
                    else
                    {
                        try
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
                                try
                                {
                                    // Hydra 2625A format: +NNNN.NE+N (always one decimal digit before E)
                                    // Serial corruption may drop the decimal point (e.g. +0029E+0 instead of +002.9E+0)
                                    // Re-insert decimal before last mantissa digit when missing
                                    string valStr = results[i].Trim();
                                    if (valStr.IndexOf('.') < 0)
                                    {
                                        int eIdx = valStr.IndexOf('E');
                                        if (eIdx > 1)
                                        {
                                            valStr = valStr.Insert(eIdx - 1, ".");
                                        }
                                    }
                                    double val = double.Parse(valStr, System.Globalization.CultureInfo.InvariantCulture);
                                    Measurements.Add(val);
                                }
                                catch (Exception ex)
                                {
                                    Trace.TraceWarning("[LogsResponse] Measurement parse failed at index {0}: {1}", i, ex.Message);
                                    Measurements.Add(0);
                                }
                            }
                            try
                            {
                                DigitalIOLineState = int.Parse(results[results.Length - 2]);
                            }
                            catch (Exception ex)
                            {
                                Trace.TraceWarning("[LogsResponse] DigitalIOLineState parse: {0}", ex.Message);
                            }
                            try
                            {
                                Totalizer = results[results.Length - 1];
                            }
                            catch (Exception ex)
                            {
                                Trace.TraceWarning("[LogsResponse] Totalizer parse: {0}", ex.Message);
                            }
                        }
                        catch (Exception ex)
                        {
                            Trace.TraceWarning("[LogsResponse] Hydra log block parse: {0}", ex.Message);
                        }
                    }

                    break;
                default:
                    break;
            }
        }

        #endregion
    }
}
