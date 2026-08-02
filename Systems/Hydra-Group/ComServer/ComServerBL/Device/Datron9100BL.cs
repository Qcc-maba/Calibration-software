using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Business logic for the Datron/Wavetek 9100 calibrator over GPIB (used as a master reference).
    /// <para>
    /// The 9100 is a full SCPI-1994 instrument. Command strings live in the single
    /// <see cref="Datron9100Commands"/> table below and were verified live (2026-08-02) against a
    /// Wavetek 9100 (fw 5.12) at GPIB PAD 18 — see docs/devices/Datron-9100/.
    /// </para>
    /// <para>
    /// ⚠️ SAFETY / MODE: SCPI subsystem commands are only honoured in the 9100's MANUAL mode
    /// (User's Handbook Vol.2 §6.3.1.6). The init sequence therefore starts with <c>*RST</c>, which
    /// reverts the unit to Manual mode AND forces the output OFF (Appendix D.3). This is a calibrator
    /// that SOURCES real voltage/current: the output is only enabled by an explicit
    /// <see cref="Datron9100Commands.BuildOutputOn"/> when a calibration target is commanded — it is
    /// never auto-enabled by the init or read loop below.
    /// </para>
    /// </summary>
    public class Datron9100BL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        // The Read loop below queries the present DC-voltage setpoint (SOUR:VOLTage?), so values are
        // bounded by the configured range; this guard just rejects any non-finite/sentinel reply.
        private const double OverloadValue = 9.0e37;

        private int _consecutiveFailures;
        private const int MaxConsecutiveFailures = 10;

        #endregion

        #region ctor

        public Datron9100BL(Datron9100BLCore parent) : base(parent)
        {
        }

        #endregion

        #region overridden from CommonBL.BaseBLDevice

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            if (this.StateMachine_InitSystem == null)
            {
                this.StateMachine_InitSystem = new CommonBL.SingleState(STATE_MACHINE__InitSystem, "Init System")
                {
                    Action_DoWork = StateWork__InitSystem
                };
            }

            if (this.StateMachine_Read == null)
            {
                this.StateMachine_Read = new CommonBL.SingleState(STATE_MACHINE__Read, "Read")
                {
                    Action_DoWork = StateWork__Read
                };
            }

            this.StateMachine_InitSystem.IsActive = true;
            this.StateMachine_Read.IsActive = true;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_InitSystem,
                this.StateMachine_Read,
            };

            return states.OrderBy(s => s.State).ToArray();
        }

        protected override bool OnStepStart(DeviceSteps step)
        {
            switch (step)
            {
                case DeviceSteps.Start: return true;
                case DeviceSteps.Routine: return false;
                case DeviceSteps.Close: return true;
            }
            return false;
        }

        public override void OnEvent(DeviceEventArgs e)
        {
            base.OnEvent(e);
        }

        #endregion

        #region state machine :: InitSystem

        /// <summary>
        /// Sends the init sequence one command per step, driven entirely by
        /// <see cref="Datron9100Commands.InitSequence"/>. Adding/removing/reordering init commands is a
        /// single-line edit in that table — no change is needed here.
        /// </summary>
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var sequence = Datron9100Commands.InitSequence;
            int step = singleState.CurrentStep;

            if (step >= 0 && step < sequence.Length)
            {
                var req = new InitSystemRequest();
                req.Packet = sequence[step].Build();
                HW_Device.Reset(req);
                return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Read

        private CommonBL.SingleState.StepWorkResponses StateWork__Read(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                    req.Packet = Datron9100Commands.BuildReadValue();
                    HW_Device.GetLogs(req, ReadValueCallback);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void ReadValueCallback(LogsResponse response)
        {
            try
            {
                if (response != null && response.Result &&
                    response.Measurements != null && response.Measurements.Count > 0)
                {
                    _consecutiveFailures = 0;
                    var raw = response.Measurements[0];
                    // The 9100 is a SOURCE: this value is the echoed DC-voltage setpoint (SOUR:VOLTage?
                    // returns e.g. "1.000000E+00"), not a measurement. Unit/format interpretation belongs
                    // in the parser/calculator; per-function readback (CURR?/RES?/…) is added there.
                    if (Math.Abs(raw) < OverloadValue)
                    {
                        HW_Device.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { raw });
                    }
                }
                else
                {
                    _consecutiveFailures++;
                }
            }
            finally
            {
                // Continuous read, self-recovering; stop re-queueing if the device is gone or keeps failing
                // so the callback chain cannot pile unbounded requests onto a disconnected instrument.
                if (HW_Device != null && HW_Device.IsConnected && _consecutiveFailures < MaxConsecutiveFailures)
                {
                    var next = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                    next.Packet = Datron9100Commands.BuildReadValue();
                    HW_Device.GetLogs(next, ReadValueCallback);
                }
            }
        }

        #endregion
    }

    /// <summary>The 9100 source functions and their SCPI :FUNCtion:SHAPe tokens (Vol.2 §6.6.4).</summary>
    public enum Datron9100Function
    {
        Dc,
        Sine,
        Pulse,
        Square,
        Impulse,
        Triangle,
        Trapezoid,
        SymSquare,
    }

    /// <summary>
    /// The single source of truth for every command the Datron/Wavetek 9100 BL sends.
    /// <para>
    /// Real SCPI-1994 commands, verified live 2026-08-02 (Wavetek 9100 fw 5.12, GPIB PAD 18). Every
    /// string is centralised in <see cref="HydraProtocolHelper"/>'s "Datron / Wavetek 9100" region;
    /// this class only composes them into the init sequence and the output/read helpers.
    /// </para>
    /// <para>
    /// ⚠️ Output sourcing: <see cref="BuildOutputOn"/> energises the terminals with real V/I. Only call
    /// it after selecting a function and setpoint for a commanded calibration target, and pair it with
    /// <see cref="BuildOutputOff"/>. The init sequence deliberately leaves the output OFF.
    /// </para>
    /// </summary>
    public static class Datron9100Commands
    {
        /// <summary>One labelled init command: a human-readable purpose plus the packet it builds.</summary>
        public sealed class InitCommand
        {
            /// <summary>What this step achieves (kept for logs).</summary>
            public string Purpose { get; private set; }

            /// <summary>Builds the wire packet.</summary>
            public Func<Common.HardwarePacket> Build { get; private set; }

            public InitCommand(string purpose, Func<Common.HardwarePacket> build)
            {
                Purpose = purpose;
                Build = build;
            }
        }

        /// <summary>
        /// Ordered init sequence, one command per state-machine step. *RST forces Manual mode + output
        /// OFF (the safe, remote-enabling state); *CLS clears the status/error registers. No source
        /// value is set and the output stays OFF until an explicit calibration target is commanded.
        /// </summary>
        public static readonly InitCommand[] InitSequence =
        {
            new InitCommand("reset -> Manual mode, output OFF (*RST)", () => HydraProtocolHelper.Build_D9100_Reset()),
            new InitCommand("clear status/error (*CLS)", () => HydraProtocolHelper.Build_D9100_ClearStatus()),
        };

        /// <summary>Maps a source function to its SCPI :FUNCtion:SHAPe token.</summary>
        public static string ToScpiShape(Datron9100Function function)
        {
            switch (function)
            {
                case Datron9100Function.Dc: return "DC";
                case Datron9100Function.Sine: return "SINusoid";
                case Datron9100Function.Pulse: return "PULSe";
                case Datron9100Function.Square: return "SQUare";
                case Datron9100Function.Impulse: return "IMPulse";
                case Datron9100Function.Triangle: return "TRIangle";
                case Datron9100Function.Trapezoid: return "TRAPezoid";
                case Datron9100Function.SymSquare: return "SYMSquare";
                default: return "DC";
            }
        }

        // ── Status / identification (read-only, safe) ────────────────────────────
        public static Common.HardwarePacket BuildReset() { return HydraProtocolHelper.Build_D9100_Reset(); }
        public static Common.HardwarePacket BuildClearStatus() { return HydraProtocolHelper.Build_D9100_ClearStatus(); }
        public static Common.HardwarePacket BuildIdentify() { return HydraProtocolHelper.Build_D9100_Identify(); }
        public static Common.HardwarePacket BuildOperationComplete() { return HydraProtocolHelper.Build_D9100_OperationComplete(); }
        public static Common.HardwarePacket BuildReadError() { return HydraProtocolHelper.Build_D9100_ReadError(); }
        public static Common.HardwarePacket BuildQueryOutputState() { return HydraProtocolHelper.Build_D9100_QueryOutputState(); }
        public static Common.HardwarePacket BuildQueryFunction() { return HydraProtocolHelper.Build_D9100_QueryFunction(); }

        // ── Output configuration (energises terminals only via BuildOutputOn) ─────
        public static Common.HardwarePacket BuildSelectFunction(Datron9100Function function) { return HydraProtocolHelper.Build_D9100_SelectFunction(ToScpiShape(function)); }
        public static Common.HardwarePacket BuildSetVoltage(double volts) { return HydraProtocolHelper.Build_D9100_SetVoltage(volts); }
        public static Common.HardwarePacket BuildSetVoltageHigh(double volts) { return HydraProtocolHelper.Build_D9100_SetVoltageHigh(volts); }
        public static Common.HardwarePacket BuildSetVoltageLow(double volts) { return HydraProtocolHelper.Build_D9100_SetVoltageLow(volts); }
        public static Common.HardwarePacket BuildSetCurrent(double amps) { return HydraProtocolHelper.Build_D9100_SetCurrent(amps); }
        public static Common.HardwarePacket BuildSetResistance(double ohms) { return HydraProtocolHelper.Build_D9100_SetResistance(ohms); }
        public static Common.HardwarePacket BuildSetCapacitance(double farads) { return HydraProtocolHelper.Build_D9100_SetCapacitance(farads); }
        public static Common.HardwarePacket BuildSetFrequency(double hertz) { return HydraProtocolHelper.Build_D9100_SetFrequency(hertz); }
        public static Common.HardwarePacket BuildOutputOn() { return HydraProtocolHelper.Build_D9100_OutputOn(); }
        public static Common.HardwarePacket BuildOutputOff() { return HydraProtocolHelper.Build_D9100_OutputOff(); }

        /// <summary>
        /// The query issued in a loop by the Read state — the present DC-voltage setpoint
        /// (SOUR:VOLTage?). The 9100 is a source, so this echoes the commanded value rather than
        /// measuring one; per-function readback is interpreted in the parser/calculator.
        /// </summary>
        public static Common.HardwarePacket BuildReadValue()
        {
            return HydraProtocolHelper.Build_D9100_QueryVoltage();
        }
    }
}
