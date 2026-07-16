using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection.Emit;
using System.Runtime;
using System.Runtime.InteropServices;
using System.Runtime.Remoting.Channels;
using System.Text;
using System.Text.RegularExpressions;
using static Maba.VCT.CommServer.BL.HydraDevices.Settings.HardwareBL_DeviceType;
using static Maba.VCT.CommServer.BL.HydraDevices.Settings.SensorType;
using static System.Net.WebRequestMethods;

namespace Maba.VCT.Common
{
    public static class HydraProtocolHelper
    {

        #region Common Commands
        private static string ID_Command = "*IDN?";
        private static string Reset_Command = "*RST";
        private static string Clear_Command = "*CLS";
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
        private static string RoutScan_Command = "ROUT:SCAN ";
        private static string LogClear2_Command = "DATA:CLE";
        private static string LogIntervalBetweenScans_Command = "TRIG:TIM ";
        private static string LogStartScanIndex_Command = "TRIG:COUN 0";
        private static string LogStartScan_Command = "INIT";
        private static string LogDataPoint_Command = "DATA:POIN?";
        private static string LogDataRead_Command = "DATA:READ?";


        #endregion

        #region Additel Commands
        //private static string ModuleInformation = "MOD:INF?";
        private static string ScanData = "SCAN:DATA:Last?";
        //private static string StartScan = "SCAN:STAR";

        #endregion

        #region Agilent Commands

        private static string RemoteOperationMode = "SYSt:REM";

        #endregion

        #region TTI commands
        private static string TTI_ID = "GET STATUS\r";
        private static string TTI_Data = "GET DATA\r";

        #endregion

        #region Optidew Commands
        private static string GetDewPoiny = "06";
        private static string GetTemperature = "08";

        #endregion

        #region Instek Commands
        private static string InstekRout = "ROUT:SCAN (@)";
        private static string InstekScan = "ROUT:SCAN ";
        private static string InstekTriggerTime = "TRIG:SOUR TIM";
        private static string InstekTriggerInterval = "TRIG:TIM ";
        private static string InstekTriggerCount = "TRIG:COUN INF";
        private static string InstekTriggerConf = "CONF";
        private static string InstekReset = "ABOR";
        #endregion

        #region Public Static Methods

        #region Hydra 2 Methods


        public static Common.HardwarePacket Build_GetFullDate()
        {
            return new HardwarePacket(GetFullDate_Command, true);
        }
        public static IPacket Build_ID_Packet()
        {
            return new Common.HardwarePacket(ID_Command, true);
        }
        public static Common.HardwarePacket Build_ResetPacket(bool wait4Response)
        {
            return new Common.HardwarePacket(Reset_Command, wait4Response);
        }
        public static Common.HardwarePacket Build_SetDatePacket()
        {
            var month = DateTime.Now.Month.ToString();
            var day = DateTime.Now.Day.ToString();
            var year = (DateTime.Now.Year - 2000).ToString();
            var command = SetDate_Command + " " + month + "," + day + "," + year;
            return new Common.HardwarePacket(command, true);
        }
        public static Common.HardwarePacket Build_SetTimePacket()
        {
            var hour = DateTime.Now.Hour.ToString();
            var minutes = DateTime.Now.Minute.ToString();
            var command = SetTime_Command + " " + hour + "," + minutes;
            return new Common.HardwarePacket(command, true);
        }
        public static HardwarePacket Build_PrintPacket()
        {
            return new Common.HardwarePacket(Print_Command, true);
        }
        public static HardwarePacket Build_PrintTypePacket()
        {
            return new Common.HardwarePacket(PrintType_Command, true);
        }
        public static HardwarePacket Build_SetRatePacket(MeasurementRates Rate)
        {
            return new Common.HardwarePacket(Rate_Command + ((int)Rate).ToString(), true);
        }
        public static HardwarePacket Build_SetFormatPacket()
        {
            return new Common.HardwarePacket(Format_Command, true);
        }

        public static HardwarePacket Build_InitialChannelsPacket(int channelNumber, HardwareBL_DeviceType setting)
        {
            if (setting == null || setting.Sensor == null || channelNumber > setting.MaxNumOfChannels)
            {
                throw new ArgumentException();
            }
            string measureType = "";

            switch (setting.Sensor.MeasureType)
            {
                case MeasureTypes.TEMP:
                    measureType = "TEMP";
                    break;
                case MeasureTypes.VDC:
                    measureType = "VDC";
                    break;
                default:
                    break;
            }

            string termocoupleType = "K";

            switch (setting.Sensor.ThermocoupleType)
            {
                case ThermocoupleTypes.K:
                    termocoupleType = "K";
                    break;
                case ThermocoupleTypes.T:
                    termocoupleType = "T";
                    break;
                case ThermocoupleTypes.R:
                    termocoupleType = "R";
                    break;
                default:
                    break;
            }
            var command = InitChannel_Command + channelNumber + "," + measureType + "," + termocoupleType;
            return new Common.HardwarePacket(command, true);
        }



        public static HardwarePacket Build_SetIntervalPacket(RateRequest rateRequest)
        {
            var command = Interval_Command + rateRequest.IntervalHours + "," + rateRequest.IntervalMinutes + "," + rateRequest.IntervalSeconds;
            return new Common.HardwarePacket(command, true);
        }
        public static HardwarePacket Build_ClearLogsPacket()
        {
            return new Common.HardwarePacket(LogClear_Command, true);
        }
        public static HardwarePacket Build_ScanLogsPacket(LogsRequest req)
        {
            return new Common.HardwarePacket(LogScan_Command + ((int)req.LogCommand).ToString(), true);
        }
        public static HardwarePacket Build_LogCountPacket()
        {
            return new Common.HardwarePacket(LogCount_Command, true);
        }
        public static HardwarePacket Build_GetChannelLogPacket(int channleNumber)
        {
            return new Common.HardwarePacket(GetChannelLog_Command + channleNumber.ToString(), true);
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
        public static Common.HardwarePacket Build_Reset2Packet()
        {
            return new Common.HardwarePacket(Reset_Command, false);
        }
        public static HardwarePacket BuildDisplayStatPacket()
        {
            return new Common.HardwarePacket(SetDisplayStat_Command, false);
        }
        public static HardwarePacket BuildRoutPacket()
        {
            return new Common.HardwarePacket(SetRout_Command, false);
        }
        public static HardwarePacket Build_SetDate2Packet()
        {
            var month = DateTime.Now.Month.ToString();
            var day = DateTime.Now.Day.ToString();
            var year = (DateTime.Now.Year).ToString();
            var command = SetDate2_Command + " " + year + "," + month + "," + day;
            return new Common.HardwarePacket(command, false);
        }
        public static HardwarePacket Build_SetTime2Packet()
        {
            var hour = DateTime.Now.Hour.ToString();
            var minutes = DateTime.Now.Minute.ToString();
            var seconds = DateTime.Now.Second.ToString();
            var command = SetTime2_Command + " " + hour + "," + minutes + "," + seconds;
            return new Common.HardwarePacket(command, false);
        }
        public static HardwarePacket Build_SetRate2Packet(MeasurementRates rate)
        {
            string Rate = rate == MeasurementRates.FAST ? "FAST" : "SLOW";
            return new Common.HardwarePacket(SetRate_Command + Rate, false);

        }
        public static HardwarePacket Build_InitChannelsPacket(int channelNumber, HardwareBL_DeviceType settings)
        {
            if (channelNumber > settings.MaxNumOfChannels)
            {
                Trace.Write("Number of channels > {0}", settings.MaxNumOfChannels.ToString());
            }
            string Command = "";

            switch (settings.Sensor.MeasureType)
            {
                case MeasureTypes.TEMP:
                    Command = "TEMP";
                    switch (settings.Sensor.SensType)
                    {
                        case SensorTypes.TCouple:
                            Command += ":TC:TYPE ";
                            switch (settings.Sensor.ThermocoupleType)
                            {
                                case ThermocoupleTypes.K:
                                    Command += "K";
                                    break;
                                case ThermocoupleTypes.T:
                                    Command += "T";
                                    break;
                                case ThermocoupleTypes.R:
                                    Command = "R";
                                    break;
                            }
                            break;
                        case SensorTypes.RTD:
                        case SensorTypes.FRTD:
                            Command = ":A385";
                            break;
                        default:
                            break;
                    }
                    break;
                case MeasureTypes.VDC:
                    Command = "VOLT:DC";
                    break;
                default:
                    break;
            }
            string stringChannelNum = channelNumber == 0 ? "1" : channelNumber.ToString();
            var command = Command + ", " + "(@" + stringChannelNum + ")";
            return new Common.HardwarePacket(command, false);
        }
        public static HardwarePacket Build_RoutScanPacket(List<int> Channels)
        {
            StringBuilder temp = new StringBuilder();
            temp.Append("(@");
            for (int i = 0; i < Channels.Count; i++)
            {
                temp.Append(Channels[i]).ToString();
                temp.Append(", ");
            }
            temp.Remove(temp.Length - 2, 2);
            temp.Append(")");
            var command = RoutScan_Command + temp.ToString();
            return new Common.HardwarePacket(command, false);
        }
        public static HardwarePacket Build_ClearLogs2Packet()
        {
            return new Common.HardwarePacket(LogClear2_Command, false);
        }
        public static HardwarePacket Build_IntervalBetweenScanPacket(int Interval)
        {
            return new Common.HardwarePacket(LogIntervalBetweenScans_Command + (Interval).ToString(), false);
        }
        public static HardwarePacket Build_ScanIndex()
        {
            return new Common.HardwarePacket(LogStartScanIndex_Command, false);
        }
        public static HardwarePacket Build_ScanLogs2Packet()
        {
            return new Common.HardwarePacket(LogStartScan_Command, false);
        }
        public static HardwarePacket Build_DataPointPacket()
        {
            return new Common.HardwarePacket(LogDataPoint_Command, true);
        }
        public static HardwarePacket Build_DataReadPacket()
        {
            return new Common.HardwarePacket(LogDataRead_Command, true);
        }



        #endregion

        #region Agilent Methods
        public static HardwarePacket Build_RemotePacket()
        {
            return new HardwarePacket(RemoteOperationMode, false);
        }
        public static Common.HardwarePacket buildClearBuffer()
        {
            return new HardwarePacket(Clear_Command, false);
        }

        public static HardwarePacket Build_Configuration(SensorType sensor)
        {
            string command = "";
            switch (sensor.MeasureType)
            {
                case MeasureTypes.None:
                case MeasureTypes.TEMP:
                    break;
                case MeasureTypes.VDC:
                    command = "CONF:VOLT:DC";
                    break;
                default:
                    break;
            }
            switch (sensor.SensType)
            {
                case SensorTypes.None:
                    break;
                case SensorTypes.FRTD:
                    command = "CONF:FRES";

                    break;
                case SensorTypes.RTD:
                    command = "CONF:RES";
                    break;
                default:
                    break;
            }

            return new HardwarePacket(command, false);
        }

        public static HardwarePacket Build_AutoRange(SensorType sensor)
        {
            string command = "";
            switch (sensor.MeasureType)
            {
                case MeasureTypes.None:
                case MeasureTypes.TEMP:
                    break;
                case MeasureTypes.VDC:
                    command = "VOLT:DC:RANG:AUTO ON";
                    break;
                default:
                    break;
            }
            switch (sensor.SensType)
            {
                case SensorTypes.None:
                    break;
                case SensorTypes.FRTD:
                    command = "FRES:RANG:AUTO ON";
                    break;
                case SensorTypes.RTD:
                    command = "RES:RANG:AUTO ON";
                    break;
                default:
                    break;
            }
            return new HardwarePacket(command, false);
        }

        public static HardwarePacket BuildRead()
        {
            return new HardwarePacket(LogDataPoint_Command, true);
        }

        // 34401A: trigger + return one measurement (verified: READ? -> scientific-notation value).
        public static HardwarePacket Build_ReadValue()
        {
            return new HardwarePacket("READ?", true);
        }

        #endregion

        #region TTI 20 Methods
        public static IPacket Build_TTI_ID_Packet()
        {
            return new Common.HardwarePacket(TTI_ID, true);
        }
        public static HardwarePacket GetTTIData()
        {
            return new Common.HardwarePacket(TTI_Data, true);
        }
        #endregion

        #region Additel Methods
        //public static HardwarePacket Build_ModuleInformation()
        //{
        //    return new HardwarePacket(ModuleInformation, true);
        //}
        public static HardwarePacket Build_ScanData()
        {
            return new HardwarePacket(ScanData, true);
        }

        public static HardwarePacket Build_ChannelConfiguration(int channelNumber, int numberOfWires, int Mytype)
        {
            string channelConfig;

            if (channelNumber > 10)
            {
                channelConfig = string.Format(@"CHAN:CONF ""REF-{2}A"",1,""AAA"",{0},0,0,1,1,""{1},0""", Mytype, numberOfWires, channelNumber - 10);
            }
            else if (channelNumber < 10)
            {
                channelConfig = string.Format(@"CHAN:CONF ""CH1-0{2}A"",1,""AAA"",{0},0,0,1,1,""{1},0""", Mytype, numberOfWires, channelNumber);
            }
            else
            {
                channelConfig = string.Format(@"CHAN:CONF ""CH1-10A"",1,""AAA"",{0},0,0,1,1,""{1},0""", Mytype, numberOfWires, channelNumber);
            }
            return new HardwarePacket(channelConfig, false);
        }




        //public static HardwarePacket Build_ScanStart()
        //{
        //    return new HardwarePacket(StartScan, true);
        //}

        #endregion

        #region Optidew
        public static HardwarePacket Build_OptidewGetDewpoint()
        {
            return new HardwarePacket(GetDewPoiny, true);
        }
        public static HardwarePacket Build_OptidewGetTemperature()
        {
            return new HardwarePacket(GetTemperature, true);
        }
        #endregion

        #region Instek Methods
        //public static HardwarePacket Build_InstekRout()
        //{
        //    return new HardwarePacket(InstekRout, true);
        //}

        public static HardwarePacket Build_InstekScan(List<int> channels)
        {
            StringBuilder temp = new StringBuilder();
            temp.Append("(@");
            for (int i = 0; i < channels.Count; i++)
            {
                temp.Append(channels[i]).ToString();
                temp.Append(", ");
            }
            temp.Remove(temp.Length - 2, 2);
            temp.Append(")");
            var command = InstekScan + temp.ToString();
            return new Common.HardwarePacket(command, false);

        }

        public static HardwarePacket Build_InstekTrigSoruce()
        {
            return new Common.HardwarePacket(InstekTriggerTime, false);
        }

        public static HardwarePacket Build_InstekScanInterval(int interval)
        {
            return new Common.HardwarePacket(InstekTriggerInterval + interval, false);
        }

        public static HardwarePacket Build_InstekTrigerCount()
        {
            return new Common.HardwarePacket(InstekTriggerCount, false);

        }

        public static HardwarePacket Build_InstekConf(HardwareBL_DeviceType instek)
        {
            string Command = InstekTriggerConf;
            switch (instek.Sensor.MeasureType)
            {
                case MeasureTypes.TEMP:
                    Command += ":TEMP";
                    switch (instek.Sensor.SensType)
                    {
                        case SensorTypes.TCouple:
                            Command += ":TC, ";
                            switch (instek.Sensor.ThermocoupleType)
                            {
                                case ThermocoupleTypes.K:
                                    Command += "K,";
                                    break;
                                case ThermocoupleTypes.T:
                                    Command += "T,";
                                    break;
                                case ThermocoupleTypes.R:
                                    Command = "R,";
                                    break;
                            }
                            break;
                        case SensorTypes.RTD:
                        case SensorTypes.FRTD:
                            Command = ":A385";
                            break;
                        default:
                            break;
                    }
                    break;
                case MeasureTypes.VDC:
                    Command = "VOLT:DC";
                    break;
                default:
                    break;
            }
            StringBuilder temp = new StringBuilder();
            temp.Append("(@");
            for (int i = 0; i < instek.Channels.Count; i++)
            {
                temp.Append(instek.Channels[i]).ToString();
                temp.Append(", ");
            }
            temp.Remove(temp.Length - 2, 2);
            temp.Append(")");
            var command = Command + temp.ToString();
            return new Common.HardwarePacket(command, false);
        }
        public static HardwarePacket Build_InstekRead(MeasureTypes measureType, List<int> channel)
        {
            return new Common.HardwarePacket("READ?", true);
        }

        public static HardwarePacket Build_InstekReset()
        {
            return new Common.HardwarePacket(InstekReset, true);
        }
        public static HardwarePacket Build_InstekRout()
        {
            return new Common.HardwarePacket(InstekRout, true);
        }


        #endregion
        #endregion

    }
}
