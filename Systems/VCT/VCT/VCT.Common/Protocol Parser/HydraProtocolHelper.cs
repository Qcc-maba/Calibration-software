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

        #region Datron / Wavetek 9100 Methods (SCPI 1994)

        // Verified live 2026-08-02 against a Wavetek 9100 (fw 5.12) at GPIB PAD 18.
        // The 9100 is a full SCPI-1994 instrument, but SCPI subsystem commands are only honoured in
        // MANUAL mode (see User's Handbook Vol.2 §6.3.1.6). *RST reverts the unit to Manual mode AND
        // forces OUTPut:STATe OFF (Appendix D.3), so it is the safe entry point for remote control.
        // Output is NEVER sourced until an explicit OUTPut ON — never auto-enable it in a poll loop.
        private static string D9100_Reset_Command = "*RST";                    // -> Manual mode, DC, 1V, OUTPUT OFF
        private static string D9100_Clear_Command = "*CLS";
        private static string D9100_Id_Command = "*IDN?";
        private static string D9100_Opc_Command = "*OPC?";
        private static string D9100_Error_Command = "SYST:ERRor?";
        private static string D9100_OutputOn_Command = "OUTP:STATe ON";
        private static string D9100_OutputOff_Command = "OUTP:STATe OFF";
        private static string D9100_OutputStateQuery_Command = "OUTP:STATe?";
        private static string D9100_Function_Command = "SOUR:FUNCtion:SHAPe "; // + DC|SINusoid|PULSe|SQUare|IMPulse|TRIangle|TRAPezoid|SYMSquare
        private static string D9100_FunctionQuery_Command = "SOUR:FUNCtion:SHAPe?";
        private static string D9100_Voltage_Command = "SOUR:VOLTage ";
        private static string D9100_VoltageQuery_Command = "SOUR:VOLTage?";
        private static string D9100_VoltageHigh_Command = "SOUR:VOLTage:HIGH ";
        private static string D9100_VoltageLow_Command = "SOUR:VOLTage:LOW ";
        private static string D9100_Current_Command = "SOUR:CURRent ";
        private static string D9100_Resistance_Command = "SOUR:RESistance ";
        private static string D9100_Capacitance_Command = "SOUR:CAPacitance ";
        private static string D9100_Frequency_Command = "SOUR:FREQuency ";

        // Format a numeric setpoint the way the 9100 accepts (invariant, e.g. "10.5", "0.2", "1000").
        private static string D9100_Num(double value)
        {
            return value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public static HardwarePacket Build_D9100_Reset() { return new HardwarePacket(D9100_Reset_Command, false); }
        public static HardwarePacket Build_D9100_ClearStatus() { return new HardwarePacket(D9100_Clear_Command, false); }
        public static HardwarePacket Build_D9100_Identify() { return new HardwarePacket(D9100_Id_Command, true); }
        public static HardwarePacket Build_D9100_OperationComplete() { return new HardwarePacket(D9100_Opc_Command, true); }
        public static HardwarePacket Build_D9100_ReadError() { return new HardwarePacket(D9100_Error_Command, true); }
        public static HardwarePacket Build_D9100_OutputOn() { return new HardwarePacket(D9100_OutputOn_Command, false); }
        public static HardwarePacket Build_D9100_OutputOff() { return new HardwarePacket(D9100_OutputOff_Command, false); }
        public static HardwarePacket Build_D9100_QueryOutputState() { return new HardwarePacket(D9100_OutputStateQuery_Command, true); }
        public static HardwarePacket Build_D9100_SelectFunction(string scpiShape) { return new HardwarePacket(D9100_Function_Command + scpiShape, false); }
        public static HardwarePacket Build_D9100_QueryFunction() { return new HardwarePacket(D9100_FunctionQuery_Command, true); }
        public static HardwarePacket Build_D9100_SetVoltage(double volts) { return new HardwarePacket(D9100_Voltage_Command + D9100_Num(volts), false); }
        public static HardwarePacket Build_D9100_QueryVoltage() { return new HardwarePacket(D9100_VoltageQuery_Command, true); }
        public static HardwarePacket Build_D9100_SetVoltageHigh(double volts) { return new HardwarePacket(D9100_VoltageHigh_Command + D9100_Num(volts), false); }
        public static HardwarePacket Build_D9100_SetVoltageLow(double volts) { return new HardwarePacket(D9100_VoltageLow_Command + D9100_Num(volts), false); }
        public static HardwarePacket Build_D9100_SetCurrent(double amps) { return new HardwarePacket(D9100_Current_Command + D9100_Num(amps), false); }
        public static HardwarePacket Build_D9100_SetResistance(double ohms) { return new HardwarePacket(D9100_Resistance_Command + D9100_Num(ohms), false); }
        public static HardwarePacket Build_D9100_SetCapacitance(double farads) { return new HardwarePacket(D9100_Capacitance_Command + D9100_Num(farads), false); }
        public static HardwarePacket Build_D9100_SetFrequency(double hertz) { return new HardwarePacket(D9100_Frequency_Command + D9100_Num(hertz), false); }

        #endregion

        #region Keysight EDUX1002A / InfiniiVision 1000 X-Series (SCPI)

        // Keysight InfiniiVision EDUX1002A oscilloscope, 50 MHz / 2 analog channels.
        // Command set per the InfiniiVision 1000 X-Series Programmer's Guide (Keysight 9018-07554).
        // Replies are <value><NL> in NR3 (scientific) notation; a measurement that cannot be made
        // returns +9.9E+37 (see KeysightEdux1002aReadings.IsMeasurementError).
        // NOTE: the scope's only remote-control port is the rear USB *device* port (USBTMC) - it has
        // no LAN, GPIB or RS-232. The command text below is transport-independent.
        private static string EDUX_Reset_Command = "*RST";
        private static string EDUX_Clear_Command = "*CLS";
        private static string EDUX_Id_Command = "*IDN?";
        private static string EDUX_Error_Command = ":SYSTem:ERRor?";
        private static string EDUX_AutoScale_Command = ":AUToscale";
        private static string EDUX_Run_Command = ":RUN";
        private static string EDUX_Stop_Command = ":STOP";
        private static string EDUX_TimebaseMain_Command = ":TIMebase:MODE MAIN";
        private static string EDUX_ChannelDisplay_Command = ":CHANnel{0}:DISPlay {1}";
        private static string EDUX_MeasureSource_Command = ":MEASure:SOURce CHANnel";

        /// <summary>Formats an analog channel as the SCPI source parameter ("CHANnel1").</summary>
        private static string EDUX_Source(int channel)
        {
            return "CHANnel" + channel.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public static HardwarePacket Build_Edux1002a_Reset() { return new HardwarePacket(EDUX_Reset_Command, false); }
        public static HardwarePacket Build_Edux1002a_ClearStatus() { return new HardwarePacket(EDUX_Clear_Command, false); }
        public static HardwarePacket Build_Edux1002a_Identify() { return new HardwarePacket(EDUX_Id_Command, true); }
        public static HardwarePacket Build_Edux1002a_ReadError() { return new HardwarePacket(EDUX_Error_Command, true); }
        public static HardwarePacket Build_Edux1002a_TimebaseMain() { return new HardwarePacket(EDUX_TimebaseMain_Command, false); }

        /// <summary>
        /// :AUToscale - brings a live signal onto the screen. Without it the scope keeps the *RST
        /// default view and every :MEASure? query answers +9.9E+37 whenever the signal does not
        /// happen to fit it.
        /// </summary>
        public static HardwarePacket Build_Edux1002a_AutoScale() { return new HardwarePacket(EDUX_AutoScale_Command, false); }

        public static HardwarePacket Build_Edux1002a_Run() { return new HardwarePacket(EDUX_Run_Command, false); }
        public static HardwarePacket Build_Edux1002a_Stop() { return new HardwarePacket(EDUX_Stop_Command, false); }

        /// <summary>:CHANnel&lt;n&gt;:DISPlay - a channel must be displayed for it to be measurable.</summary>
        public static HardwarePacket Build_Edux1002a_ChannelDisplay(int channel, bool on)
        {
            var command = string.Format(System.Globalization.CultureInfo.InvariantCulture,
                                        EDUX_ChannelDisplay_Command, channel, on ? "1" : "0");
            return new HardwarePacket(command, false);
        }

        /// <summary>:MEASure:SOURce - sets the default source for measurements issued without one.</summary>
        public static HardwarePacket Build_Edux1002a_SetMeasureSource(int channel)
        {
            return new HardwarePacket(EDUX_MeasureSource_Command + channel.ToString(System.Globalization.CultureInfo.InvariantCulture), false);
        }

        /// <summary>
        /// Builds the :MEASure? query for the quantity the operator configured, always with an
        /// explicit source so the reading cannot be attributed to the wrong channel:
        /// <list type="bullet">
        /// <item>VoltageDC  -> :MEASure:VAVerage? DISPlay,CHANnel&lt;n&gt; (DC average over the screen)</item>
        /// <item>VoltagePP  -> :MEASure:VPP? CHANnel&lt;n&gt;</item>
        /// <item>VoltageRMS -> :MEASure:VRMS? DISPlay,AC,CHANnel&lt;n&gt;</item>
        /// <item>Frequency  -> :MEASure:FREQuency? CHANnel&lt;n&gt;</item>
        /// </list>
        /// Anything else falls back to peak-to-peak, the usual scope verification point.
        /// </summary>
        public static HardwarePacket Build_Edux1002a_Measure(SensorType sensor, int channel)
        {
            var source = EDUX_Source(channel);
            string command;

            switch (sensor == null ? MeasureTypes.None : sensor.MeasureType)
            {
                case MeasureTypes.VoltageDC:
                    command = ":MEASure:VAVerage? DISPlay," + source;
                    break;
                case MeasureTypes.VoltageRMS:
                    command = ":MEASure:VRMS? DISPlay,AC," + source;
                    break;
                case MeasureTypes.Frequency:
                    command = ":MEASure:FREQuency? " + source;
                    break;
                case MeasureTypes.VoltagePP:
                default:
                    command = ":MEASure:VPP? " + source;
                    break;
            }

            return new HardwarePacket(command, true);
        }

        #endregion

        #region Pendulum CNT-90 counter (SCPI, NATive language)

        // Pendulum CNT-90 timer/counter/analyzer. Verified live 2026-09-01 against
        // "PENDULUM, CNT-90, 938636, V1.14 28 Jun 2006" at GPIB address 7.
        //
        // Two behaviours drive the shape of these commands:
        //  * :SYSTem:LANGuage selects the command set. NATive is what the handbook documents;
        //    COMPatible is Agilent 53131/53132 emulation with a different command set entirely.
        //  * With no signal on the input, a frequency measurement BLOCKS - the counter waits for
        //    edges that never come, and unlike an oscilloscope it returns no sentinel. The documented
        //    9.91E37 "no valid result" value only appears in COMPatible mode. :SYSTem:TOUT (and
        //    :TOUT:AUTO) are accepted and read back correctly but were observed NOT to release the
        //    query. The BL therefore probes for a signal with a voltage measurement, which always
        //    answers quickly, before committing to a frequency query.
        private static string CNT90_Reset_Command = "*RST";
        private static string CNT90_Clear_Command = "*CLS";
        private static string CNT90_Id_Command = "*IDN?";
        private static string CNT90_Opc_Command = "*OPC?";
        private static string CNT90_Error_Command = ":SYSTem:ERRor?";
        private static string CNT90_NativeLanguage_Command = ":SYSTem:LANGuage NATive";
        private static string CNT90_FormatAscii_Command = ":FORMat ASCii";
        private static string CNT90_TimeoutOn_Command = ":SYSTem:TOUT ON";
        private static string CNT90_TimeoutAuto_Command = ":SYSTem:TOUT:AUTO ON";
        private static string CNT90_TimeoutTime_Command = ":SYSTem:TOUT:TIME ";

        /// <summary>Formats an input as the CNT-90 channel parameter ("(@1)").</summary>
        private static string CNT90_Channel(int channel)
        {
            return "(@" + channel.ToString(System.Globalization.CultureInfo.InvariantCulture) + ")";
        }

        private static string CNT90_Num(double value)
        {
            return value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public static HardwarePacket Build_Cnt90_Reset() { return new HardwarePacket(CNT90_Reset_Command, false); }
        public static HardwarePacket Build_Cnt90_ClearStatus() { return new HardwarePacket(CNT90_Clear_Command, false); }
        public static HardwarePacket Build_Cnt90_Identify() { return new HardwarePacket(CNT90_Id_Command, true); }
        public static HardwarePacket Build_Cnt90_OperationComplete() { return new HardwarePacket(CNT90_Opc_Command, true); }
        public static HardwarePacket Build_Cnt90_ReadError() { return new HardwarePacket(CNT90_Error_Command, true); }

        /// <summary>Forces the documented (native) command set, in case the unit was left in 53131/53132 emulation.</summary>
        public static HardwarePacket Build_Cnt90_SelectNativeLanguage() { return new HardwarePacket(CNT90_NativeLanguage_Command, false); }

        public static HardwarePacket Build_Cnt90_FormatAscii() { return new HardwarePacket(CNT90_FormatAscii_Command, false); }

        /// <summary>*RST leaves the measurement timeout OFF; enable it so a stalled measurement is bounded.</summary>
        public static HardwarePacket Build_Cnt90_TimeoutOn() { return new HardwarePacket(CNT90_TimeoutOn_Command, false); }

        /// <summary>Short timeout from INIT to the first start trigger - "is there any signal at all?".</summary>
        public static HardwarePacket Build_Cnt90_TimeoutAuto() { return new HardwarePacket(CNT90_TimeoutAuto_Command, false); }

        /// <summary>Measurement timeout in seconds (range 0.01 - 1000, 10 ms resolution).</summary>
        public static HardwarePacket Build_Cnt90_TimeoutTime(double seconds) { return new HardwarePacket(CNT90_TimeoutTime_Command + CNT90_Num(seconds), false); }

        /// <summary>:CONFigure:FREQuency (@n) - sets up the measurement without starting it.</summary>
        public static HardwarePacket Build_Cnt90_ConfigureFrequency(int channel) { return new HardwarePacket(":CONFigure:FREQuency " + CNT90_Channel(channel), false); }

        /// <summary>:READ? - identical to :ABORt;:INITiate;:FETCh?; makes the measurement and returns it.</summary>
        public static HardwarePacket Build_Cnt90_Read() { return new HardwarePacket(":READ?", true); }

        public static HardwarePacket Build_Cnt90_MeasureFrequency(int channel) { return new HardwarePacket(":MEASure:FREQuency? " + CNT90_Channel(channel), true); }
        public static HardwarePacket Build_Cnt90_MeasurePeriod(int channel) { return new HardwarePacket(":MEASure:PERiod? " + CNT90_Channel(channel), true); }

        /// <summary>
        /// Peak voltage on an input. Unlike a frequency measurement this always answers quickly
        /// (~380 ms on an open input, reading a few mV), which makes it the BL's signal-presence probe.
        /// </summary>
        public static HardwarePacket Build_Cnt90_MeasureVoltageMax(int channel) { return new HardwarePacket(":MEASure:VOLTage:MAXimum? " + CNT90_Channel(channel), true); }
        public static HardwarePacket Build_Cnt90_MeasureVoltageMin(int channel) { return new HardwarePacket(":MEASure:VOLTage:MINimum? " + CNT90_Channel(channel), true); }

        #endregion

        #region Siglent SDG6052X generator (Siglent shorthand, NOT SCPI subsystems)

        // Siglent SDG6052X arbitrary waveform generator. Verified live 2026-09-01 against
        // "Siglent Technologies,SDG6052X,SDG6XEBD4R0879,6.01.01.35R5B1" on USBTMC.
        //
        // ⚠️ NO *RST HERE. On the SDG *RST means "restore default settings" - it would wipe whatever
        // the operator has dialled in on the front panel. The init sequence only identifies the unit
        // and reads its state back; it never resets it and never enables an output.
        //
        // The syntax is Siglent's own shorthand, not SCPI subsystems, and replies echo the command
        // header with unit suffixes glued onto the numbers:
        //     C1:BSWV?  ->  C1:BSWV WVTP,SINE,FRQ,1000HZ,AMP,4V,OFST,0V,...
        // Parsing therefore belongs in Sdg6052xReplies, not in the numeric paths used by the
        // SCPI instruments - double.Parse("1000HZ") throws.
        private static string SDG_Id_Command = "*IDN?";
        private static string SDG_Opc_Command = "*OPC?";
        private static string SDG_Error_Command = "SYST:ERR?";

        /// <summary>Formats an output channel as the Siglent prefix ("C1").</summary>
        private static string SDG_Channel(int channel)
        {
            return "C" + channel.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        private static string SDG_Num(double value)
        {
            return value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public static HardwarePacket Build_Sdg_Identify() { return new HardwarePacket(SDG_Id_Command, true); }
        public static HardwarePacket Build_Sdg_OperationComplete() { return new HardwarePacket(SDG_Opc_Command, true); }
        public static HardwarePacket Build_Sdg_ReadError() { return new HardwarePacket(SDG_Error_Command, true); }

        /// <summary>C&lt;n&gt;:BSWV? - reads back the whole basic-wave parameter set for one channel.</summary>
        public static HardwarePacket Build_Sdg_QueryBasicWave(int channel) { return new HardwarePacket(SDG_Channel(channel) + ":BSWV?", true); }

        /// <summary>C&lt;n&gt;:OUTP? - reads the output state, load and polarity.</summary>
        public static HardwarePacket Build_Sdg_QueryOutput(int channel) { return new HardwarePacket(SDG_Channel(channel) + ":OUTP?", true); }

        /// <summary>C&lt;n&gt;:BSWV WVTP,&lt;type&gt; - selects the waveform without touching its parameters.</summary>
        public static HardwarePacket Build_Sdg_SetWaveType(int channel, string waveType) { return new HardwarePacket(SDG_Channel(channel) + ":BSWV WVTP," + waveType, false); }

        public static HardwarePacket Build_Sdg_SetFrequency(int channel, double hertz) { return new HardwarePacket(SDG_Channel(channel) + ":BSWV FRQ," + SDG_Num(hertz), false); }
        public static HardwarePacket Build_Sdg_SetAmplitude(int channel, double voltsPeakToPeak) { return new HardwarePacket(SDG_Channel(channel) + ":BSWV AMP," + SDG_Num(voltsPeakToPeak), false); }
        public static HardwarePacket Build_Sdg_SetOffset(int channel, double volts) { return new HardwarePacket(SDG_Channel(channel) + ":BSWV OFST," + SDG_Num(volts), false); }
        public static HardwarePacket Build_Sdg_SetPhase(int channel, double degrees) { return new HardwarePacket(SDG_Channel(channel) + ":BSWV PHSE," + SDG_Num(degrees), false); }

        /// <summary>C&lt;n&gt;:OUTP LOAD,&lt;50|HZ&gt; - termination the generator compensates its amplitude for.</summary>
        public static HardwarePacket Build_Sdg_SetLoad(int channel, string load) { return new HardwarePacket(SDG_Channel(channel) + ":OUTP LOAD," + load, false); }

        /// <summary>
        /// ⚠️ ENERGISES THE OUTPUT. Only call for a commanded target, and pair with
        /// <see cref="Build_Sdg_OutputOff"/>. The init sequence never calls this.
        /// </summary>
        public static HardwarePacket Build_Sdg_OutputOn(int channel) { return new HardwarePacket(SDG_Channel(channel) + ":OUTP ON", false); }

        public static HardwarePacket Build_Sdg_OutputOff(int channel) { return new HardwarePacket(SDG_Channel(channel) + ":OUTP OFF", false); }

        #endregion

        #region PRODIGIT 3111 electronic load (partial SCPI subset over RS-232)

        // PRODIGIT 3111 DC electronic load, 80 V / 70 A / 350 W. Mapped live 2026-09-02 against the
        // instrument on COM10 at 115200 8-N-1 - the command set below is what it ACTUALLY answered,
        // not what a manual claims; no programming manual for this model could be found.
        //
        // Three things make it unlike the SCPI instruments here:
        //  * 115200 baud, not the 9600 the other serial devices use.
        //  * *IDN? answers a bare model token, "PRODIGIT_3111" - no vendor, serial or firmware field.
        //  * It implements only a fragment of SCPI. *OPC?, *ESR?, *STB? and SYST:ERR? are all silent,
        //    and ERR? answers a constant (21) that does not clear and does not change after a bad
        //    command. There is therefore NO way to ask whether a command was accepted: silence is the
        //    only failure signal.
        //
        // ⚠️ This instrument SINKS current. Commands that arm the load are deliberately absent from
        // this region: everything below is a query. Enabling a load draws power from whatever is wired
        // to its input, so that must be a considered, commanded action - not something a BL can reach
        // by accident.
        private static string PRODIGIT_Id_Command = "*IDN?";
        private static string PRODIGIT_Version_Command = "VER?";
        private static string PRODIGIT_MeasureVoltage_Command = "MEAS:VOLT?";
        private static string PRODIGIT_MeasureCurrent_Command = "MEAS:CURR?";
        private static string PRODIGIT_MeasurePower_Command = "MEAS:POW?";
        private static string PRODIGIT_LoadState_Command = "LOAD?";
        private static string PRODIGIT_Mode_Command = "MODE?";
        private static string PRODIGIT_Error_Command = "ERR?";

        public static HardwarePacket Build_Prodigit_Identify() { return new HardwarePacket(PRODIGIT_Id_Command, true); }
        public static HardwarePacket Build_Prodigit_Version() { return new HardwarePacket(PRODIGIT_Version_Command, true); }
        public static HardwarePacket Build_Prodigit_MeasureVoltage() { return new HardwarePacket(PRODIGIT_MeasureVoltage_Command, true); }
        public static HardwarePacket Build_Prodigit_MeasureCurrent() { return new HardwarePacket(PRODIGIT_MeasureCurrent_Command, true); }
        public static HardwarePacket Build_Prodigit_MeasurePower() { return new HardwarePacket(PRODIGIT_MeasurePower_Command, true); }

        /// <summary>LOAD? - 0 when the load input is off. Read-only; there is no enable command here.</summary>
        public static HardwarePacket Build_Prodigit_QueryLoadState() { return new HardwarePacket(PRODIGIT_LoadState_Command, true); }

        public static HardwarePacket Build_Prodigit_QueryMode() { return new HardwarePacket(PRODIGIT_Mode_Command, true); }

        /// <summary>
        /// ERR? - answered a constant 21 throughout mapping, unchanged by a deliberately bogus
        /// command and not cleared by reading. Kept for diagnostics; do NOT treat it as an error queue.
        /// </summary>
        public static HardwarePacket Build_Prodigit_ReadError() { return new HardwarePacket(PRODIGIT_Error_Command, true); }

        /// <summary>The measurement query for the quantity the family is configured to report.</summary>
        public static HardwarePacket Build_Prodigit_Measure(SensorType sensor)
        {
            switch (sensor == null ? MeasureTypes.None : sensor.MeasureType)
            {
                case MeasureTypes.Current:
                    return Build_Prodigit_MeasureCurrent();
                case MeasureTypes.Power:
                    return Build_Prodigit_MeasurePower();
                case MeasureTypes.VoltageDC:
                default:
                    return Build_Prodigit_MeasureVoltage();
            }
        }

        #endregion

        #region HP 53181A counter (SCPI 1992.0)

        // HP 53181A frequency counter. Verified live 2026-09-02 against
        // "HEWLETT-PACKARD,53181A,0,3703" at GPIB address 3 (*OPT? -> "0,030").
        //
        // It shares the CNT-90's defining trait: with no signal on the input, a frequency measurement
        // BLOCKS - it waits for edges that never arrive and returns nothing (measured: 10 s and still
        // no reply). A voltage measurement always answers quickly (~600 ms), so the BL uses that as a
        // signal-presence guard before committing to a frequency query, exactly as Cnt90BL does.
        //
        // Unlike the CNT-90 it has a real SCPI error queue: :SYST:ERR? answers +0,"No error".
        private static string HP53181_Reset_Command = "*RST";
        private static string HP53181_Clear_Command = "*CLS";
        private static string HP53181_Id_Command = "*IDN?";
        private static string HP53181_Options_Command = "*OPT?";
        private static string HP53181_Error_Command = ":SYST:ERR?";
        private static string HP53181_Function_Command = ":FUNC?";

        /// <summary>Formats an input as the 53181A channel parameter ("(@1)").</summary>
        private static string HP53181_Channel(int channel)
        {
            return "(@" + channel.ToString(System.Globalization.CultureInfo.InvariantCulture) + ")";
        }

        public static HardwarePacket Build_Hp53181a_Reset() { return new HardwarePacket(HP53181_Reset_Command, false); }
        public static HardwarePacket Build_Hp53181a_ClearStatus() { return new HardwarePacket(HP53181_Clear_Command, false); }
        public static HardwarePacket Build_Hp53181a_Identify() { return new HardwarePacket(HP53181_Id_Command, true); }
        public static HardwarePacket Build_Hp53181a_QueryOptions() { return new HardwarePacket(HP53181_Options_Command, true); }
        public static HardwarePacket Build_Hp53181a_ReadError() { return new HardwarePacket(HP53181_Error_Command, true); }
        public static HardwarePacket Build_Hp53181a_QueryFunction() { return new HardwarePacket(HP53181_Function_Command, true); }

        /// <summary>:CONF:FREQ (@n) - sets up the measurement without starting it.</summary>
        public static HardwarePacket Build_Hp53181a_ConfigureFrequency(int channel) { return new HardwarePacket(":CONF:FREQ " + HP53181_Channel(channel), false); }

        public static HardwarePacket Build_Hp53181a_Read() { return new HardwarePacket(":READ?", true); }
        public static HardwarePacket Build_Hp53181a_MeasureFrequency(int channel) { return new HardwarePacket(":MEAS:FREQ? " + HP53181_Channel(channel), true); }
        public static HardwarePacket Build_Hp53181a_MeasurePeriod(int channel) { return new HardwarePacket(":MEAS:PER? " + HP53181_Channel(channel), true); }

        /// <summary>
        /// Peak input voltage. Answers quickly whatever is (or is not) on the input, which is what
        /// makes it usable as the BL's signal-presence guard.
        /// </summary>
        public static HardwarePacket Build_Hp53181a_MeasureVoltageMax(int channel) { return new HardwarePacket(":MEAS:VOLT:MAX? " + HP53181_Channel(channel), true); }

        public static HardwarePacket Build_Hp53181a_QueryInputImpedance() { return new HardwarePacket(":INP:IMP?", true); }
        public static HardwarePacket Build_Hp53181a_QueryInputCoupling() { return new HardwarePacket(":INP:COUP?", true); }

        #endregion

        #region Fluke 5522A calibrator (RS-232, comp mode)

        // Fluke 5522A multi-product calibrator. Verified live 2026-09-03 against
        // "FLUKE,5522A,1972905,1.1+1.3+1.8" on COM10 at 9600 8-N-1.
        //
        // ⚠️⚠️ THIS INSTRUMENT SOURCES UP TO 1000 V AND 20 A. ⚠️⚠️
        // OPER energises the output terminals for real. It is built here because a calibration target
        // needs it, but it is never issued by the BL's init or read loop - only by an explicit
        // commanded target, exactly as with the Datron 9100. STBY is its counterpart and is safe.
        //
        // Two instrument settings this depends on, both in SETUP and both needing STORE CHANGES:
        //   * HOST = serial. The manual is explicit that IEEE-488 and RS-232 cannot both be active;
        //     while HOST is gpib the serial port is dead.
        //   * REMOTE I/F = comp. In term (the factory default) the calibrator echoes the command and
        //     appends an "N> " prompt, so one query yields several CRLF-delimited packets and the
        //     shared parser sees a mess. In comp it answers with the reply alone.
        private static string F5522_Reset_Command = "*RST";
        private static string F5522_Clear_Command = "*CLS";
        private static string F5522_Id_Command = "*IDN?";
        private static string F5522_Options_Command = "*OPT?";
        private static string F5522_Error_Command = "ERR?";
        private static string F5522_Fault_Command = "FAULT?";
        private static string F5522_OutputQuery_Command = "OUT?";
        private static string F5522_OperateQuery_Command = "OPER?";
        private static string F5522_FunctionQuery_Command = "FUNC?";
        private static string F5522_RangeQuery_Command = "RANGE?";
        private static string F5522_OnTimeQuery_Command = "ONTIME?";
        private static string F5522_TempStandardQuery_Command = "TEMP_STD?";
        private static string F5522_Standby_Command = "STBY";
        private static string F5522_Operate_Command = "OPER";
        private static string F5522_Output_Command = "OUT ";

        private static string F5522_Num(double value)
        {
            return value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        // ── Read-only, all verified against the instrument ───────────────────────
        public static HardwarePacket Build_F5522a_Identify() { return new HardwarePacket(F5522_Id_Command, true); }
        public static HardwarePacket Build_F5522a_QueryOptions() { return new HardwarePacket(F5522_Options_Command, true); }
        public static HardwarePacket Build_F5522a_ReadError() { return new HardwarePacket(F5522_Error_Command, true); }
        public static HardwarePacket Build_F5522a_ReadFault() { return new HardwarePacket(F5522_Fault_Command, true); }
        public static HardwarePacket Build_F5522a_QueryOutput() { return new HardwarePacket(F5522_OutputQuery_Command, true); }
        public static HardwarePacket Build_F5522a_QueryOperate() { return new HardwarePacket(F5522_OperateQuery_Command, true); }
        public static HardwarePacket Build_F5522a_QueryFunction() { return new HardwarePacket(F5522_FunctionQuery_Command, true); }
        public static HardwarePacket Build_F5522a_QueryRange() { return new HardwarePacket(F5522_RangeQuery_Command, true); }
        public static HardwarePacket Build_F5522a_QueryOnTime() { return new HardwarePacket(F5522_OnTimeQuery_Command, true); }
        public static HardwarePacket Build_F5522a_QueryTempStandard() { return new HardwarePacket(F5522_TempStandardQuery_Command, true); }

        // ── State changing, but SAFE ─────────────────────────────────────────────
        /// <summary>*RST - resets to the power-up state, which includes standby (output off).</summary>
        public static HardwarePacket Build_F5522a_Reset() { return new HardwarePacket(F5522_Reset_Command, false); }
        public static HardwarePacket Build_F5522a_ClearStatus() { return new HardwarePacket(F5522_Clear_Command, false); }

        /// <summary>STBY - disconnects the output terminals. Always safe; the counterpart to OPER.</summary>
        public static HardwarePacket Build_F5522a_Standby() { return new HardwarePacket(F5522_Standby_Command, false); }

        /// <summary>
        /// OUT &lt;amplitude&gt; &lt;unit&gt; - sets the output value. This only SELECTS the value; the
        /// terminals stay disconnected until <see cref="Build_F5522a_Operate"/>.
        /// </summary>
        public static HardwarePacket Build_F5522a_SetOutput(double amplitude, string unit)
        {
            return new HardwarePacket(F5522_Output_Command + F5522_Num(amplitude) + " " + unit, false);
        }

        /// <summary>
        /// OUT &lt;amplitude&gt; &lt;unit&gt;, &lt;frequency&gt; HZ - an ac output, value and frequency together.
        /// Still does not energise anything on its own.
        /// </summary>
        public static HardwarePacket Build_F5522a_SetOutput(double amplitude, string unit, double hertz)
        {
            return new HardwarePacket(
                F5522_Output_Command + F5522_Num(amplitude) + " " + unit + ", " + F5522_Num(hertz) + " HZ", false);
        }

        /// <summary>
        /// ⚠️ OPER - ENERGISES THE OUTPUT TERMINALS with the selected value, up to 1000 V / 20 A.
        /// Only for a commanded calibration target, and always paired with
        /// <see cref="Build_F5522a_Standby"/>. Never called from an init or a polling loop.
        /// </summary>
        public static HardwarePacket Build_F5522a_Operate() { return new HardwarePacket(F5522_Operate_Command, false); }

        #endregion

        #region Meatest M-142 multifunction calibrator (SCPI)

        // Meatest M-142. Commands taken from the official manual (meatest.com/files/download/man/m142m.pdf);
        // NOT yet verified against hardware.
        //
        // Two things set it apart from the other sources here:
        //  * It is also a METER. MEAS? returns a real measured value and MEAS:CONF? says what the
        //    internal multimeter is set to, so this instrument can report a measurement rather than
        //    only echo its own setpoint.
        //  * Interfaces: GPIB (address 2 from the factory) AND RS-232, both standard. RS-232 is
        //    8-N-1, 150-19200 baud from the menu, optional XON/XOFF, and a STRAIGHT 1:1 cable -
        //    not the null-modem the Fluke 5522A needs.
        //
        // ⚠️ It sources real voltage and current, and with the 50-turn coil option reaches 1000 A.
        // OUTP ON is built but is never issued by the init or the read loop.
        private static string M142_Id_Command = "*IDN?";
        private static string M142_Reset_Command = "*RST";
        private static string M142_Clear_Command = "*CLS";
        private static string M142_Opc_Command = "*OPC?";
        private static string M142_OutputOn_Command = "OUTP ON";
        private static string M142_OutputOff_Command = "OUTP OFF";
        private static string M142_OutputQuery_Command = "OUTP?";
        private static string M142_MeasureQuery_Command = "MEAS?";
        private static string M142_MeasureConfigQuery_Command = "MEAS:CONF?";
        private static string M142_FunctionQuery_Command = "SOUR:FUNC:SHAP?";

        private static string M142_Num(double value)
        {
            return value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public static HardwarePacket Build_M142_Identify() { return new HardwarePacket(M142_Id_Command, true); }
        public static HardwarePacket Build_M142_Reset() { return new HardwarePacket(M142_Reset_Command, false); }
        public static HardwarePacket Build_M142_ClearStatus() { return new HardwarePacket(M142_Clear_Command, false); }
        public static HardwarePacket Build_M142_OperationComplete() { return new HardwarePacket(M142_Opc_Command, true); }

        /// <summary>OUTP? - returns ON or OFF. Read-only.</summary>
        public static HardwarePacket Build_M142_QueryOutput() { return new HardwarePacket(M142_OutputQuery_Command, true); }

        public static HardwarePacket Build_M142_QueryFunction() { return new HardwarePacket(M142_FunctionQuery_Command, true); }

        /// <summary>MEAS? - the value the internal multimeter is reading, in exponential form.</summary>
        public static HardwarePacket Build_M142_Measure() { return new HardwarePacket(M142_MeasureQuery_Command, true); }

        /// <summary>
        /// MEAS:CONF? - what the internal meter is set to
        /// { VOLT | CURR | MVOLT | RES | FREQ | TEMPerature:RTD | TEMPerature:THERmocouple | OFF }.
        /// OFF means the meter is not measuring, and MEAS? has nothing to report.
        /// </summary>
        public static HardwarePacket Build_M142_QueryMeasureConfig() { return new HardwarePacket(M142_MeasureConfigQuery_Command, true); }

        /// <summary>Reads back a source setpoint without changing it.</summary>
        public static HardwarePacket Build_M142_QuerySetpoint(SensorType sensor)
        {
            switch (sensor == null ? MeasureTypes.None : sensor.MeasureType)
            {
                case MeasureTypes.Current: return new HardwarePacket("SOUR:CURR?", true);
                case MeasureTypes.Resistance: return new HardwarePacket("SOUR:RES?", true);
                case MeasureTypes.Frequency: return new HardwarePacket("SOUR:FREQ?", true);
                default: return new HardwarePacket("SOUR:VOLT?", true);
            }
        }

        // ── Setpoints: they select a value, they do not connect the terminals ────
        public static HardwarePacket Build_M142_SetVoltage(double volts) { return new HardwarePacket("SOUR:VOLT " + M142_Num(volts), false); }
        public static HardwarePacket Build_M142_SetCurrent(double amps) { return new HardwarePacket("SOUR:CURR " + M142_Num(amps), false); }
        public static HardwarePacket Build_M142_SetResistance(double ohms) { return new HardwarePacket("SOUR:RES " + M142_Num(ohms), false); }
        public static HardwarePacket Build_M142_SetCapacitance(double farads) { return new HardwarePacket("SOUR:CAP " + M142_Num(farads), false); }
        public static HardwarePacket Build_M142_SetFrequency(double hertz) { return new HardwarePacket("SOUR:FREQ " + M142_Num(hertz), false); }
        public static HardwarePacket Build_M142_SelectShape(string shape) { return new HardwarePacket("SOUR:FUNC:SHAP " + shape, false); }

        /// <summary>OUTP OFF - disconnects the terminals. Always safe.</summary>
        public static HardwarePacket Build_M142_OutputOff() { return new HardwarePacket(M142_OutputOff_Command, false); }

        /// <summary>
        /// ⚠️ OUTP ON - CONNECTS THE OUTPUT TERMINALS. With the 50-turn coil option selected this
        /// instrument reaches 1000 A. Only for a commanded calibration target, always paired with
        /// <see cref="Build_M142_OutputOff"/>. Never called from an init or a polling loop.
        /// </summary>
        public static HardwarePacket Build_M142_OutputOn() { return new HardwarePacket(M142_OutputOn_Command, false); }

        #endregion

        #region Fluke 5322A electrical tester calibrator (SCPI)

        // Fluke 5322A. Commands taken from the official Operators Manual
        // (5322A___openg0000.pdf); NOT yet verified against hardware.
        //
        // ⚠️ IDENTITY IS NOT FIXED. The manual is explicit: with 5320A emulation Off the *IDN? reply
        // is "FLUKE,5322A,<serial>,<firmware>", and with it On the SAME instrument answers
        // "FLUKE,5320A,<serial>,<four firmware parts>". A menu setting therefore changes the model
        // the instrument reports, so identification must accept both spellings or the unit silently
        // stops being claimed.
        //
        // ⚠️ Over USB, SYST:REM (or SYST:RWL) must be sent before anything else or the instrument
        // stays in local mode - the same requirement the 34401A has over RS-232.
        //
        // Only one interface is active at a time (Setup > Interface > Active interface), exactly the
        // trap the 5522A has: while GPIB is selected the USB port is dead.
        private static string F5322_Id_Command = "*IDN?";
        private static string F5322_Reset_Command = "*RST";
        private static string F5322_Clear_Command = "*CLS";
        private static string F5322_Options_Command = "*OPT?";
        private static string F5322_Remote_Command = "SYST:REM";
        private static string F5322_OutputOn_Command = "OUTP ON";
        private static string F5322_OutputOff_Command = "OUTP OFF";
        private static string F5322_OutputQuery_Command = "OUTP?";
        private static string F5322_ModeQuery_Command = "SAF:MODE?";

        private static string F5322_Num(double value)
        {
            return value.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }

        public static HardwarePacket Build_F5322a_Identify() { return new HardwarePacket(F5322_Id_Command, true); }
        public static HardwarePacket Build_F5322a_QueryOptions() { return new HardwarePacket(F5322_Options_Command, true); }
        public static HardwarePacket Build_F5322a_Reset() { return new HardwarePacket(F5322_Reset_Command, false); }
        public static HardwarePacket Build_F5322a_ClearStatus() { return new HardwarePacket(F5322_Clear_Command, false); }

        /// <summary>SYST:REM - mandatory over USB before any other command, else the unit stays local.</summary>
        public static HardwarePacket Build_F5322a_Remote() { return new HardwarePacket(F5322_Remote_Command, false); }

        /// <summary>OUTP? - returns ON or OFF. Read-only.</summary>
        public static HardwarePacket Build_F5322a_QueryOutput() { return new HardwarePacket(F5322_OutputQuery_Command, true); }

        /// <summary>
        /// SAF:MODE? - which calibration function is selected
        /// (GBR, HRES, LRES, IDAC, RCDT, LOOP, VOLT, MET, HIPL, FLI, ...).
        /// </summary>
        public static HardwarePacket Build_F5322a_QueryMode() { return new HardwarePacket(F5322_ModeQuery_Command, true); }

        /// <summary>SAF:GBR? - the ground-bond resistance setpoint, in exponential form.</summary>
        public static HardwarePacket Build_F5322a_QueryGroundBond() { return new HardwarePacket("SAF:GBR?", true); }

        /// <summary>Sets the ground-bond resistance in ohms. Selects the value; does not connect it.</summary>
        public static HardwarePacket Build_F5322a_SetGroundBond(double ohms) { return new HardwarePacket("SAF:GBR " + F5322_Num(ohms), false); }

        /// <summary>OUTP OFF - removes the output signal from the terminals. Always safe.</summary>
        public static HardwarePacket Build_F5322a_OutputOff() { return new HardwarePacket(F5322_OutputOff_Command, false); }

        /// <summary>
        /// ⚠️ OUTP ON - APPLIES THE OUTPUT SIGNAL TO THE TERMINALS. This is an electrical-safety
        /// tester calibrator: it sources hipot and flash-test levels. Only for a commanded target,
        /// always paired with <see cref="Build_F5322a_OutputOff"/>. Never from an init or a loop.
        /// </summary>
        public static HardwarePacket Build_F5322a_OutputOn() { return new HardwarePacket(F5322_OutputOn_Command, false); }

        #endregion

        #endregion

    }
}
