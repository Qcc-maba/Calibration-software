using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Fluke 5322A multifunction electrical tester calibrator. NOT yet verified against hardware -
    /// the commands and reply shapes come from the Operators Manual.
    /// <para>
    /// ⚠️⚠️ THIS INSTRUMENT SOURCES HIPOT AND FLASH-TEST LEVELS. ⚠️⚠️ The rule, identical to
    /// <see cref="Datron9100BL"/> and <see cref="Fluke5522aBL"/>: the output is applied to the
    /// terminals only by an explicit commanded calibration target through
    /// <see cref="Fluke5322aCommands.BuildOutputOn"/>. The init below and the read loop never issue
    /// it - the init drives the instrument the other way, to output off.
    /// </para>
    /// <para>
    /// <b>⚠️ Its model name is a menu setting.</b> With 5320A emulation off the instrument answers
    /// <c>*IDN?</c> with "FLUKE,5322A,...", and with emulation on the same unit answers
    /// "FLUKE,5320A,...". Identification therefore matches BOTH tokens (see
    /// <c>HardwareDeviceHost.IsFluke5322a</c>) and normalises either to the SN "5322A" - an operator
    /// flipping that menu must not quietly remove the instrument from the server.
    /// </para>
    /// <para>
    /// <b>⚠️ Over USB the remote command is mandatory.</b> USB presents a virtual COM port (8-N-1)
    /// and the instrument stays in local mode until it receives <c>SYST:REM</c>, so that command is
    /// the first thing the init sends - the same requirement the Agilent 34401A has over RS-232.
    /// </para>
    /// <para>
    /// Only one interface is active at a time (Setup &gt; Interface &gt; Active interface), exactly
    /// the trap the 5522A has: while GPIB is the active interface the USB port is dead, and the
    /// symptom is total silence rather than an error.
    /// </para>
    /// See docs/devices/electronics/Fluke-5322A/protocol.md.
    /// </summary>
    public class Fluke5322aBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        private const int MaxConsecutiveFailures = 10;

        /// <summary>Where the read cycle currently is. One outstanding query at a time, as always.</summary>
        private enum ReadPhase
        {
            /// <summary>OUTP? - is the output signal applied. Observational only.</summary>
            OutputState,
            /// <summary>SAF:MODE? - which calibration function is selected.</summary>
            Mode,
            /// <summary>SAF:GBR? - the ground-bond resistance setpoint.</summary>
            Setpoint,
        }

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;
        private int _consecutiveFailures;

        private ReadPhase _phase;

        /// <summary>The last SAF:MODE? answer, kept so the setpoint phase knows how to label the value.</summary>
        private string _mode = string.Empty;

        #endregion

        #region ctor

        public Fluke5322aBL(Fluke5322aBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;
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
        /// Drives the calibrator to a known, de-energised, remote-controllable state. Every step is
        /// either read-only or moves the instrument AWAY from sourcing - see
        /// <see cref="Fluke5322aCommands.InitSequence"/>.
        /// </summary>
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var sequence = Fluke5322aCommands.InitSequence;
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

        #region state machine :: Read (output state -> mode -> setpoint)

        private CommonBL.SingleState.StepWorkResponses StateWork__Read(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    QueryOutputState();
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>
        /// Asks whether the output signal is applied. Purely observational - the BL reports this and
        /// never changes it - but on an instrument that sources hipot levels it belongs in the log
        /// beside every reading.
        /// </summary>
        private void QueryOutputState()
        {
            Send(ReadPhase.OutputState, HydraProtocolHelper.Build_F5322a_QueryOutput());
        }

        private void Send(ReadPhase phase, HardwarePacket packet)
        {
            _phase = phase;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = packet;
            HW_Device.GetLogs(req, ReadCallback);
        }

        private void ReadCallback(LogsResponse response)
        {
            var phase = _phase;

            // Read from the raw text: OUTP? answers the word ON/OFF and SAF:MODE? answers a function
            // token, neither of which any shared numeric branch can turn into a reading.
            var reply = response != null && response.Result ? response.RawText : null;

            if (string.IsNullOrEmpty(reply))
            {
                _consecutiveFailures++;
                Continue();
                return;
            }

            switch (phase)
            {
                case ReadPhase.OutputState:
                    var live = Fluke5322aReadings.IsOutputLive(reply);
                    Libs.Trace.Tracer.Info("[FLUKE 5322A] {0}: output is {1}.",
                        HW_Device.SN, live ? "APPLIED to the terminals" : "off");
                    Send(ReadPhase.Mode, HydraProtocolHelper.Build_F5322a_QueryMode());
                    return;

                case ReadPhase.Mode:
                    _mode = Fluke5322aReadings.NormalizeMode(reply);

                    // ⚠️ A setpoint query on this instrument is NOT read-only - it SELECTS that
                    // function (proven live; see Fluke5322aReadings.IsGroundBondMode). So only ask
                    // for the setpoint of the function it is ALREADY in. Asking unconditionally
                    // would drag the calibrator into Ground Bond on every single poll and quietly
                    // undo the operator's front-panel selection.
                    if (Fluke5322aReadings.IsGroundBondMode(_mode))
                    {
                        Send(ReadPhase.Setpoint, HydraProtocolHelper.Build_F5322a_QueryGroundBond());
                    }
                    else
                    {
                        Libs.Trace.Tracer.Info(
                            "[FLUKE 5322A] {0}: function is {1}; this BL can only read a Ground Bond setpoint, so nothing is broadcast (asking anyway would switch the instrument).",
                            HW_Device.SN, string.IsNullOrEmpty(_mode) ? "unknown" : _mode);
                        Continue();
                    }
                    return;

                case ReadPhase.Setpoint:
                    Publish(reply);
                    Continue();
                    return;
            }

            Continue();
        }

        private void Publish(string reply)
        {
            double value;
            if (!Fluke5322aReadings.TryParseValue(reply, out value))
            {
                _consecutiveFailures++;
                return;
            }

            _consecutiveFailures = 0;

            // The broadcast units come from the configured sensor (ServerCore resolves them by SN),
            // so log the unit the selected function implies too: a mismatch between the two is
            // exactly the misconfiguration that otherwise shows up as a plausible-looking wrong
            // number rather than as an error.
            Libs.Trace.Tracer.Info("[FLUKE 5322A] {0}: setpoint = {1} ({2}, mode {3}).",
                HW_Device.SN, value, Fluke5322aReadings.UnitsForMode(_mode),
                string.IsNullOrEmpty(_mode) ? "unknown" : _mode);

            HW_Device.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { value });
        }

        private void Continue()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[FLUKE 5322A] {0} consecutive failed reads on {1} - stopping until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            QueryOutputState();
        }

        #endregion
    }

    /// <summary>
    /// The single source of truth for every command the 5322A BL sends. Raw strings live in
    /// <see cref="HydraProtocolHelper"/>'s "Fluke 5322A" region; this class composes them.
    /// <para>
    /// ⚠️ <see cref="BuildOutputOn"/> applies the output signal to the terminals. The init sequence
    /// omits it by design, and so does the read loop.
    /// </para>
    /// </summary>
    public static class Fluke5322aCommands
    {
        /// <summary>One labelled init command: a human-readable purpose plus the packet it builds.</summary>
        public sealed class InitCommand
        {
            public string Purpose { get; private set; }
            public Func<Common.HardwarePacket> Build { get; private set; }

            public InitCommand(string purpose, Func<Common.HardwarePacket> build)
            {
                Purpose = purpose;
                Build = build;
            }
        }

        /// <summary>
        /// Ordered init sequence. SYST:REM comes FIRST because over USB the instrument ignores
        /// everything until it is in remote mode - a reset sent before it would be silently dropped.
        /// The explicit OUTP OFF at the end makes the de-energised state a stated intention rather
        /// than a side effect of the reset. Nothing here can source anything.
        /// </summary>
        public static readonly InitCommand[] InitSequence =
        {
            new InitCommand("take remote control - mandatory over USB (SYST:REM)", () => HydraProtocolHelper.Build_F5322a_Remote()),
            new InitCommand("reset to power-up state (*RST)", () => HydraProtocolHelper.Build_F5322a_Reset()),
            new InitCommand("clear status and error queue (*CLS)", () => HydraProtocolHelper.Build_F5322a_ClearStatus()),
            new InitCommand("force output off - terminals not energised (OUTP OFF)", () => HydraProtocolHelper.Build_F5322a_OutputOff()),
        };

        // -- Read-only -----------------------------------------------------------
        public static Common.HardwarePacket BuildIdentify() { return HydraProtocolHelper.Build_F5322a_Identify(); }
        public static Common.HardwarePacket BuildQueryOptions() { return HydraProtocolHelper.Build_F5322a_QueryOptions(); }
        public static Common.HardwarePacket BuildQueryOutput() { return HydraProtocolHelper.Build_F5322a_QueryOutput(); }
        public static Common.HardwarePacket BuildQueryMode() { return HydraProtocolHelper.Build_F5322a_QueryMode(); }
        public static Common.HardwarePacket BuildQueryGroundBond() { return HydraProtocolHelper.Build_F5322a_QueryGroundBond(); }

        // -- Safe state changes --------------------------------------------------
        public static Common.HardwarePacket BuildRemote() { return HydraProtocolHelper.Build_F5322a_Remote(); }
        public static Common.HardwarePacket BuildReset() { return HydraProtocolHelper.Build_F5322a_Reset(); }
        public static Common.HardwarePacket BuildClearStatus() { return HydraProtocolHelper.Build_F5322a_ClearStatus(); }
        public static Common.HardwarePacket BuildOutputOff() { return HydraProtocolHelper.Build_F5322a_OutputOff(); }

        /// <summary>Selects a ground-bond resistance. The output stays off until <see cref="BuildOutputOn"/>.</summary>
        public static Common.HardwarePacket BuildSetGroundBond(double ohms) { return HydraProtocolHelper.Build_F5322a_SetGroundBond(ohms); }

        // -- Energises the terminals ---------------------------------------------
        /// <summary>
        /// ⚠️ Applies the selected output to the terminals for real - this is an electrical-safety
        /// tester calibrator, so that includes hipot and flash-test levels. Only for a commanded
        /// calibration target, always paired with <see cref="BuildOutputOff"/>.
        /// </summary>
        public static Common.HardwarePacket BuildOutputOn() { return HydraProtocolHelper.Build_F5322a_OutputOn(); }
    }
}
