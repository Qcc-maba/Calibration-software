using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>What a DAQ-9600 channel is set up to measure, decided from the settings' sensor.</summary>
    public enum Daq9600Function
    {
        /// <summary>No supported function - the BL does not configure the instrument.</summary>
        Unsupported,
        /// <summary>Thermocouple K, T, R or S. The instrument converts to degC with its own cold junction.</summary>
        Thermocouple,
        /// <summary>PT-100, 4-wire (FRES). The BL converts ohms to degC with the sensor's own coefficients.</summary>
        Pt100FourWire,
        /// <summary>PT-100, 2-wire (RES). The lead resistance is part of the reading.</summary>
        Pt100TwoWire,
        /// <summary>DC volts, sent as volts with no compensation.</summary>
        VoltageDc,
    }

    /// <summary>
    /// GW Instek DAQ-9600 - the pure (hardware-independent) part: channel numbering, the commands the BL
    /// sends, and reading the replies. Everything here was checked against the instrument on 2026-11-26
    /// (fw M1.07_S1.02, two DAQ-901 cards, USBTMC) - see docs/devices/temperature/GW-Instek-DAQ-9600/protocol.md.
    /// </summary>
    public static class Daq9600Readings
    {
        #region channel numbering

        /// <summary>Terminals per DAQ-901 card (the two current terminals, 21 and 22, are not used).</summary>
        public const int ChannelsPerSlot = 20;

        /// <summary>Module slots in the mainframe.</summary>
        public const int Slots = 3;

        /// <summary>Channels the app can number: 20 per slot.</summary>
        public const int MaxChannels = ChannelsPerSlot * Slots;

        /// <summary>
        /// The app numbers a logger's channels 1, 2, 3... (and overwrites the settings' list with that
        /// numbering), while the instrument names a channel slot*100 + terminal. App 1-20 is slot 1 (101-120),
        /// 21-40 slot 2 (201-220), 41-60 slot 3 (301-320). Measured: probes on terminals 1-5 of the slot-1 card
        /// answered on 101-105.
        /// </summary>
        public static bool TryToInstrumentChannel(int appChannel, out int instrumentChannel)
        {
            instrumentChannel = 0;
            if (appChannel < 1 || appChannel > MaxChannels) return false;
            var slot = (appChannel - 1) / ChannelsPerSlot + 1;
            var terminal = (appChannel - 1) % ChannelsPerSlot + 1;
            instrumentChannel = slot * 100 + terminal;
            return true;
        }

        /// <summary>The app's number for an instrument channel (101 -> 1, 201 -> 21), or 0 when it is not one.</summary>
        public static int ToAppChannel(int instrumentChannel)
        {
            var slot = instrumentChannel / 100;
            var terminal = instrumentChannel % 100;
            if (slot < 1 || slot > Slots || terminal < 1 || terminal > ChannelsPerSlot) return 0;
            return (slot - 1) * ChannelsPerSlot + terminal;
        }

        /// <summary>
        /// The scan, in the order the instrument reports it. The DAQ-9600 always scans in ascending channel
        /// order, whatever order the list was given in (measured: ROUT:SCAN (@105,101,109) reads back as
        /// (@101,105,109) and READ? answers in that order), so the replies are mapped by this sorted list.
        /// App channels the instrument cannot have are dropped and reported in <paramref name="rejected"/>.
        /// </summary>
        public static List<int> ScanOrder(IEnumerable<int> appChannels, Daq9600Function function, out List<int> rejected)
        {
            rejected = new List<int>();
            var scan = new SortedSet<int>();
            foreach (var app in appChannels ?? Enumerable.Empty<int>())
            {
                if (!TryToInstrumentChannel(app, out var ch) || (function == Daq9600Function.Pt100FourWire && !IsFourWireSourceChannel(ch)))
                {
                    rejected.Add(app);
                    continue;
                }
                scan.Add(ch);
            }
            return scan.ToList();
        }

        /// <summary>
        /// A 4-wire channel pairs the card's first ten terminals with the last ten (terminal n with n+10), so
        /// only terminals 1-10 can name a 4-wire measurement. Pairing per the manual's DAQ-901 description; the
        /// n+10 numbering is the convention of this card style, not yet confirmed with a wired PT-100.
        /// </summary>
        public static bool IsFourWireSourceChannel(int instrumentChannel)
        {
            var terminal = instrumentChannel % 100;
            return terminal >= 1 && terminal <= ChannelsPerSlot / 2;
        }

        /// <summary>"(@101,102,105)".</summary>
        public static string ChannelList(IEnumerable<int> instrumentChannels)
        {
            return "(@" + string.Join(",", instrumentChannels.Select(c => c.ToString(CultureInfo.InvariantCulture))) + ")";
        }

        #endregion

        #region function and commands

        /// <summary>What the settings' sensor asks this instrument to measure.</summary>
        public static Daq9600Function FunctionFor(SensorType sensor)
        {
            if (sensor == null) return Daq9600Function.Unsupported;
            switch (sensor.SensType)
            {
                case SensorType.SensorTypes.TCouple:
                    return ThermocoupleLetter(sensor.ThermocoupleType) != null ? Daq9600Function.Thermocouple : Daq9600Function.Unsupported;
                case SensorType.SensorTypes.FRTD:
                    return Daq9600Function.Pt100FourWire;
                case SensorType.SensorTypes.RTD:
                    return Daq9600Function.Pt100TwoWire;
            }
            return sensor.MeasureType == SensorType.MeasureTypes.VoltageDC ? Daq9600Function.VoltageDc : Daq9600Function.Unsupported;
        }

        /// <summary>The thermocouple letter the instrument takes, or null for a type the lab does not use here.</summary>
        public static string ThermocoupleLetter(SensorType.ThermocoupleTypes type)
        {
            switch (type)
            {
                case SensorType.ThermocoupleTypes.K: return "K";
                case SensorType.ThermocoupleTypes.T: return "T";
                case SensorType.ThermocoupleTypes.R: return "R";
                case SensorType.ThermocoupleTypes.S: return "S";
            }
            return null;
        }

        /// <summary>
        /// Integration time in power-line cycles. FAST = 1 PLC (the instrument's default; 5 thermocouples in
        /// ~330-440 ms measured). SLOW = 12 PLC, the slowest and most stable setting the manual lists.
        /// </summary>
        public static string Nplc(HardwareBL_DeviceType.MeasurementRates rate)
        {
            return rate == HardwareBL_DeviceType.MeasurementRates.SLOW ? "12" : "1";
        }

        /// <summary>
        /// The whole setup, in order. The instrument has no output to energise - the DAQ-901 cards only switch
        /// inputs, and nothing here touches the digital I/O or alarm outputs (a test asserts it).
        /// <list type="bullet">
        /// <item><c>ABOR</c> + <c>*CLS</c> first: a scan still running refuses configuration (one
        /// "+261 Not able to execute while scan initiated" was seen on the bench and not reproduced since).</item>
        /// <item><c>TC:CHEC ON</c> after every thermocouple <c>CONF</c>: a CONF turns it off, and without it an
        /// open R thermocouple read 789 degC and an open S 292 degC. With it, an open input reads 9.9E37.</item>
        /// <item>The reading format is set explicitly (no channel, time, unit or alarm fields), so a front-panel
        /// change cannot break the parser.</item>
        /// <item><c>TRIG:SOUR IMM</c> + <c>TRIG:COUN 1</c>: one sweep per <c>READ?</c>. The old Instek BL set
        /// <c>TRIG:COUN INF</c>, with which <c>READ?</c> never returns.</item>
        /// </list>
        /// Returns null when the function is unsupported or no channel is left.
        /// </summary>
        public static List<string> SetupCommands(Daq9600Function function, SensorType sensor, IList<int> scan,
                                                 HardwareBL_DeviceType.MeasurementRates rate)
        {
            if (function == Daq9600Function.Unsupported || scan == null || scan.Count == 0) return null;

            var list = ChannelList(scan);
            var nplc = Nplc(rate);
            var commands = new List<string> { "ABOR", "*CLS" };

            switch (function)
            {
                case Daq9600Function.Thermocouple:
                    commands.Add("CONF:TEMP TC," + ThermocoupleLetter(sensor.ThermocoupleType) + "," + list);
                    commands.Add("TEMP:TRAN:TC:CHEC ON," + list);
                    commands.Add("UNIT:TEMP C," + list);
                    commands.Add("TEMP:NPLC " + nplc + "," + list);
                    break;
                case Daq9600Function.Pt100FourWire:
                    // 1 kOhm range: a PT-100 spans ~18-390 Ohm over -200..850 degC, which the 100 Ohm range clips
                    commands.Add("CONF:FRES 1e3," + list);
                    commands.Add("FRES:NPLC " + nplc + "," + list);
                    break;
                case Daq9600Function.Pt100TwoWire:
                    commands.Add("CONF:RES 1e3," + list);
                    commands.Add("RES:NPLC " + nplc + "," + list);
                    break;
                case Daq9600Function.VoltageDc:
                    commands.Add("CONF:VOLT:DC AUTO," + list);
                    commands.Add("VOLT:DC:NPLC " + nplc + "," + list);
                    break;
            }

            commands.Add("FORM:READ:CHAN OFF");
            commands.Add("FORM:READ:TIME OFF");
            commands.Add("FORM:READ:UNIT OFF");
            commands.Add("FORM:READ:ALAR OFF");
            commands.Add("ROUT:SCAN " + list);
            commands.Add("TRIG:SOUR IMM");
            commands.Add("TRIG:COUN 1");
            commands.Add("SYST:ERR?");
            return commands;
        }

        /// <summary>One sweep of the scan list.</summary>
        public const string ReadCommand = "READ?";

        #endregion

        #region replies

        /// <summary>The instrument's over-range / open-input value is +9.9E37.</summary>
        public const double OverloadValue = 9.0e37;

        /// <summary>True for the over-range / open-input value (and for anything that is not a number).</summary>
        public static bool IsOverload(double value)
        {
            return double.IsNaN(value) || double.IsInfinity(value) || Math.Abs(value) >= OverloadValue;
        }

        /// <summary>
        /// Reads a READ? reply: one NR3 value per scanned channel, comma-separated, ending in "\n" only
        /// ("+2.14422233E+01,+2.17258911E+01,...\n"). False - and nothing broadcast - unless every value parses
        /// and there is exactly one per channel: a reply that does not match the scan cannot be mapped to
        /// channels, and a partial one would put values on the wrong channels.
        /// </summary>
        public static bool TryParseReadings(string reply, int expectedCount, out List<double> values)
        {
            values = new List<double>();
            if (string.IsNullOrWhiteSpace(reply) || expectedCount <= 0) return false;

            var parts = reply.Trim().Split(',');
            if (parts.Length != expectedCount) { values.Clear(); return false; }

            foreach (var part in parts)
            {
                if (!double.TryParse(part.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var v))
                {
                    values.Clear();
                    return false;
                }
                values.Add(v);
            }
            return true;
        }

        /// <summary>
        /// True when a SYST:ERR? reply says the queue is empty ("+0,\"No error\""). Anything else is logged by
        /// the BL as the setup's outcome.
        /// </summary>
        public static bool IsNoError(string reply)
        {
            if (string.IsNullOrWhiteSpace(reply)) return false;
            var code = reply.Trim().Split(',')[0].Trim();
            return int.TryParse(code, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var n) && n == 0;
        }

        #endregion
    }
}
