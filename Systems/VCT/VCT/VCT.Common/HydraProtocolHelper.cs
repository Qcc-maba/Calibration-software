using Maba.VCT.Common.API.RemoteProtocolService;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Net.Http.Headers;
using System.Reflection.Emit;
using System.Runtime.Remoting.Channels;
using System.Text;
using System.Threading.Tasks;
using static Maba.VCT.Common.API.RemoteProtocolService.RateRequest;

namespace Maba.VCT.Common
{
    public static class HydraProtocolHelper
    {

        #region Common Commands
        private static string ID_Command = "*IDN?";
        private static string Reset_Command = "*RST";
        #endregion

        #region Hydra 2 Commands

        private static string SetDate_Command = "DATE";
        private static string SetTime_Command = "TIME";
        private static string GetFullDate_Command = "TIME_DATE?";
        private static string PrintType_Command = "PRINT_TYPE 1,0";
        private static string Print_Command = "PRINT 1";
        private static string Rate_Command = "RATE ";
        private static string Format_Command = "FORMAT 1";
        private static string InitChannel_Command = "FUNC ";
        private static string Interval_Command = "INTVL ";
        private static string LogClear_Command = "LOG_CLR";
        private static string LogScan_Command = "SCAN ";
        private static string LogCount_Command = "LOG_COUNT?";
        private static string GetChannelLog_Command = "LOGGED? ";

        #endregion

        #region Hydra 3 Commands

        private static string SetDisplayStat_Command = "DISP:STAT ON";
        private static string SetRout_Command = "ROUT:SCAN:RES ON";
        private static string SetDate2_Command = "SYST:DATE";
        private static string SetTime2_Command = "SYST:TIME";
        private static string SetRate_Command = "RATE ";
        private static string InitChannel2_Command = "VOLT:DC: ";
        private static string RoutScan_Command = "ROUT:SCAN ";
        private static string LogClear2_Command = "DATA:CLE";
        private static string LogIntervalBetweenScans_Command = "TRIG:TIM ";
        private static string LogStartScanIndex_Command = "TRIG:COUN 0";
        private static string LogStartScan_Command = "INIT";
        private static string LogDataPoint_Command = "DATA:POIN?";
        private static string LogDataRead_Command = "DATA:READ?";


        #endregion

        #region Public Static Methods

        #region Hydra 2 Methods

        public static Common.Packet Build_GetFullDate()
        {
            return new Packet(GetFullDate_Command, true);
        }
        public static Common.Packet Build_ID_Packet()
        {
            return new Common.Packet(ID_Command, true);
        }
        public static Common.Packet Build_ResetPacket()
        {
            return new Common.Packet(Reset_Command, true);
        }
        public static Common.Packet Build_SetDatePacket()
        {
            var month = DateTime.Now.Month.ToString();
            var day = DateTime.Now.Day.ToString();
            var year = (DateTime.Now.Year - 2000).ToString();
            var command = SetDate_Command + " " + month + "," + day + "," + year;
            return new Common.Packet(command, true);
        }
        public static Common.Packet Build_SetTimePacket()
        {
            var hour = DateTime.Now.Hour.ToString();
            var minutes = DateTime.Now.Minute.ToString();
            var command = SetTime_Command + " " + hour + "," + minutes;
            return new Common.Packet(command, true);
        }
        public static Packet Build_PrintPacket()
        {
            return new Common.Packet(Print_Command, true);
        }
        public static Packet Build_PrintTypePacket()
        {
            return new Common.Packet(PrintType_Command, true);
        }
        public static Packet Build_SetRatePacket(RateRequest.MeasurementRates Rate)
        {
            return new Common.Packet(Rate_Command + Rate.ToString(), true);
        }
        public static Packet Build_SetFormatPacket()
        {
            return new Common.Packet(Format_Command, true);
        }
        public static Packet Build_InitChannelsPacket(InitChannelsRequest initChannelsRequest)
        {
            if (initChannelsRequest == null || initChannelsRequest.ChannleNumber > initChannelsRequest.MaxChannels)
            {
                throw new ArgumentException();
            }
            string measureType = "";

            switch (InitChannelsRequest.MeasureType)
            {
                case InitChannelsRequest.MeasureTypes.VAC:
                    measureType = "VAC";
                    break;
                case InitChannelsRequest.MeasureTypes.VDC:
                    measureType = "VDC";
                    break;
                case InitChannelsRequest.MeasureTypes.OHMS:
                    measureType = "OHMS";
                    break;
                case InitChannelsRequest.MeasureTypes.FREQ:
                    measureType = "FREQ";
                    break;
                case InitChannelsRequest.MeasureTypes.TEMP:
                    measureType = "TEMP";
                    break;
                case InitChannelsRequest.MeasureTypes.OFF:
                    measureType = "OFF";
                    break;
                default:
                    break;
            }
            string termocoupleType = "";

            switch (initChannelsRequest.ThermocoupleType)
            {
                case InitChannelsRequest.ThermocoupleTypes.J:
                    termocoupleType = "J";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.K:
                    termocoupleType = "K";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.E:
                    termocoupleType = "E";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.T:
                    termocoupleType = "T";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.N:
                    termocoupleType = "N";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.R:
                    termocoupleType = "R";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.S:
                    termocoupleType = "S";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.B:
                    termocoupleType = "B";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.C:
                    termocoupleType = "C";
                    break;
                default:
                    break;
            }
            var command = InitChannel_Command + initChannelsRequest.ChannleNumber/* + "," + measureType + "," + termocoupleType*/;
            return new Common.Packet(command, true);
        }
        public static Packet Build_SetIntervalPacket(RateRequest rateRequest)
        {
            var command = Interval_Command + rateRequest.IntervalHours + "," + rateRequest.IntervalMinutes + "," + rateRequest.IntervalSeconds;
            return new Common.Packet(command, true);
        }
        public static Packet Build_ClearLogsPacket()
        {
            return new Common.Packet(LogClear_Command, true);
        }
        public static Packet Build_ScanLogsPacket(LogsRequest req)
        {
            return new Common.Packet(LogScan_Command + ((int)req.LogCommand).ToString(), true);
        }
        public static Packet Build_LogCountPacket()
        {
            return new Common.Packet(LogCount_Command, true);
        }
        public static Packet Build_GetChannelLogPacket(int channleNumber)
        {
            return new Common.Packet(GetChannelLog_Command + channleNumber.ToString(), true);
        }
        public static DateTime BuildDateFromData(string command)
        {
            string[] results = command.Replace("\r\n", "").Replace("=>", "").Split(',');
            var hours = int.Parse(results[0]);
            var minutes = int.Parse(results[1]);
            var seconds = int.Parse(results[2]);
            var month = int.Parse(results[3]);
            var day = int.Parse(results[4]);
            var year = int.Parse(results[5]) + 2000;
            return new DateTime(year, month, day, hours, minutes, seconds);
        }

        #endregion

        #region Hydra 3 Methods
        public static Common.Packet Build_Reset2Packet()
        {
            return new Common.Packet(Reset_Command, false);
        }
        public static Packet BuildDisplayStatPacket()
        {
            return new Common.Packet(SetDisplayStat_Command, false);
        }
        public static Packet BuildRoutPacket()
        {
            return new Common.Packet(SetRout_Command, false);
        }
        public static Packet Build_SetDate2Packet()
        {
            var month = DateTime.Now.Month.ToString();
            var day = DateTime.Now.Day.ToString();
            var year = (DateTime.Now.Year).ToString();
            var command = SetDate2_Command + " " + year + "," + month + "," + day;
            return new Common.Packet(command, false);
        }
        public static Packet Build_SetTime2Packet()
        {
            var hour = DateTime.Now.Hour.ToString();
            var minutes = DateTime.Now.Minute.ToString();
            var seconds = DateTime.Now.Second.ToString();
            var command = SetTime2_Command + " " + hour + "," + minutes + "," + seconds;
            return new Common.Packet(command, false);
        }
        public static Packet Build_SetRate2Packet(MeasurementRates rate)
        {
            string Rate = rate == MeasurementRates.Fast ? "FAST" : "SLOW";
            return new Common.Packet(SetRate_Command + Rate, false);

        }
        public static Packet Build_InitChannelsPacket(int channelNumber, InitChannelsRequest.ThermocoupleTypes thermocoupleType)
        {
            if (channelNumber > 200)
            {
                Trace.Write("Number of channels > 200");
            }

            string termocoupleType = "";

            switch (thermocoupleType)
            {
                case InitChannelsRequest.ThermocoupleTypes.J:
                    termocoupleType = "J";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.K:
                    termocoupleType = "K";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.E:
                    termocoupleType = "E";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.T:
                    termocoupleType = "T";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.N:
                    termocoupleType = "N";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.R:
                    termocoupleType = "R";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.S:
                    termocoupleType = "S";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.B:
                    termocoupleType = "B";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.C:
                    termocoupleType = "C";
                    break;
                case InitChannelsRequest.ThermocoupleTypes.DC:
                    termocoupleType = "VDC";
                    break;
                default:
                    break;
            }
            var command = InitChannel2_Command +/* termocoupleType + */"," + "(@00" + channelNumber.ToString() + ")";
            return new Common.Packet(command, false);
        }
        public static Packet Build_RoutScanPacket(int numberOfChannels)
        {
            StringBuilder temp = new StringBuilder();
            temp.Append("(@");
            for (int i = 0; i < numberOfChannels; i++)
            {
                temp.Append(i + 101).ToString();
                temp.Append(", ");
            }
            temp.Remove(temp.Length - 2, 2);
            temp.Append(")");
            var command = RoutScan_Command + temp.ToString();
            return new Common.Packet(command, false);
        }
        public static Packet Build_ClearLogs2Packet()
        {
            return new Common.Packet(LogClear2_Command, false);
        }
        public static Packet Build_IntervalBetweenScanPacket(LogsRequest req)
        {
            return new Common.Packet(LogIntervalBetweenScans_Command + ((int)req.IntervalBetweenScans).ToString(), false);
        }
        public static Packet Build_ScanIndex()
        {
            return new Common.Packet(LogStartScanIndex_Command, false);
        }
        public static Packet Build_ScanLogs2Packet()
        {
            return new Common.Packet(LogStartScan_Command, false);
        }
        public static Packet Build_DataPointPacket()
        {
            return new Common.Packet(LogDataPoint_Command, true);
        }
        public static Packet Build_DataReadPacket()
        {
            return new Common.Packet(LogDataRead_Command, true);
        }

        #endregion

        #endregion
    }
}
