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
    /// Fluke 5522A multi-product calibrator over RS-232.
    /// Verified live 2026-09-03 against "FLUKE,5522A,1972905,1.1+1.3+1.8" on COM10 at 9600 8-N-1.
    /// <para>
    /// ⚠️⚠️ THIS INSTRUMENT SOURCES UP TO 1000 V AND 20 A. ⚠️⚠️ The rule, identical to
    /// <see cref="Datron9100BL"/>: the output is energised only by an explicit commanded calibration
    /// target through <see cref="Fluke5522aCommands.BuildOperate"/>. The init below and the read loop
    /// never issue it — the init in fact drives the instrument the other way, into standby.
    /// </para>
    /// <para>
    /// The read loop reports the calibrator's own <c>OUT?</c> setpoint, which is what a calibration
    /// compares a meter's reading against, and logs whether the terminals are live.
    /// </para>
    /// <para>
    /// Two instrument settings this depends on (SETUP, each needing STORE CHANGES):
    /// <c>HOST = serial</c> — IEEE-488 and RS-232 cannot both be active, and while HOST is gpib the
    /// serial port is dead; and <c>REMOTE I/F = comp</c> — in term the calibrator echoes the command
    /// and appends an "N&gt; " prompt, so one query becomes several packets to the shared parser.
    /// </para>
    /// See docs/devices/electronics/Fluke-5522A/protocol.md.
    /// </summary>
    public class Fluke5522aBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        private const int MaxConsecutiveFailures = 10;

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;
        private int _consecutiveFailures;

        /// <summary>True while the outstanding request is OPER? rather than OUT?.</summary>
        private bool _awaitingOperateState;

        #endregion

        #region ctor

        public Fluke5522aBL(Fluke5522aBLCore parent) : base(parent)
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
        /// Drives the calibrator to a known, de-energised state. Every step is either read-only or
        /// moves the instrument AWAY from sourcing — see <see cref="Fluke5522aCommands.InitSequence"/>.
        /// </summary>
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var sequence = Fluke5522aCommands.InitSequence;
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

        #region state machine :: Read (setpoint + live-terminal state)

        private CommonBL.SingleState.StepWorkResponses StateWork__Read(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    QueueOperateStateQuery();
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>
        /// Asks whether the terminals are live. Purely observational — the BL reports this and never
        /// changes it — but on an instrument that can put 1000 V on a cable it is worth having in the
        /// log next to every reading.
        /// </summary>
        private void QueueOperateStateQuery()
        {
            _awaitingOperateState = true;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_F5522a_QueryOperate();
            HW_Device.GetLogs(req, ReadCallback);
        }

        private void QueueOutputQuery()
        {
            _awaitingOperateState = false;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_F5522a_QueryOutput();
            HW_Device.GetLogs(req, ReadCallback);
        }

        private void ReadCallback(LogsResponse response)
        {
            var wasOperateState = _awaitingOperateState;

            // Parsed from the raw text: an OUT? reply is a comma-separated record
            // ("0.0000000E+00,V,0E+00,0,0.00E+00") that none of the shared numeric branches can read.
            var reply = response != null && response.Result ? response.RawText : null;

            if (string.IsNullOrEmpty(reply))
            {
                _consecutiveFailures++;
                Continue();
                return;
            }

            if (wasOperateState)
            {
                var live = Fluke5522aReadings.IsOutputLive(reply);
                Libs.Trace.Tracer.Info("[FLUKE 5522A] {0}: output terminals are {1}.",
                    HW_Device.SN, live ? "LIVE" : "in standby");
                QueueOutputQuery();
                return;
            }

            Fluke5522aReadings.OutputSetting setting;
            if (Fluke5522aReadings.TryParseOutput(reply, out setting))
            {
                _consecutiveFailures = 0;
                HW_Device.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { setting.Amplitude });
            }
            else
            {
                _consecutiveFailures++;
            }

            Continue();
        }

        private void Continue()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[FLUKE 5522A] {0} consecutive failed reads on {1} - stopping until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            QueueOperateStateQuery();
        }

        #endregion
    }

    /// <summary>
    /// The single source of truth for every command the 5522A BL sends. Raw strings live in
    /// <see cref="HydraProtocolHelper"/>'s "Fluke 5522A" region; this class composes them.
    /// <para>
    /// ⚠️ <see cref="BuildOperate"/> energises the output terminals with real voltage or current.
    /// The init sequence omits it by design, and so does the read loop.
    /// </para>
    /// </summary>
    public static class Fluke5522aCommands
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
        /// Ordered init sequence. *RST returns the calibrator to its power-up state, which is standby;
        /// the explicit STBY that follows makes the de-energised end state a stated intention rather
        /// than a side effect of the reset. Nothing here can source anything.
        /// </summary>
        public static readonly InitCommand[] InitSequence =
        {
            new InitCommand("reset to power-up state (*RST)", () => HydraProtocolHelper.Build_F5522a_Reset()),
            new InitCommand("clear status and error queue (*CLS)", () => HydraProtocolHelper.Build_F5522a_ClearStatus()),
            new InitCommand("force standby - terminals disconnected (STBY)", () => HydraProtocolHelper.Build_F5522a_Standby()),
        };

        // ── Read-only ────────────────────────────────────────────────────────────
        public static Common.HardwarePacket BuildIdentify() { return HydraProtocolHelper.Build_F5522a_Identify(); }
        public static Common.HardwarePacket BuildQueryOptions() { return HydraProtocolHelper.Build_F5522a_QueryOptions(); }
        public static Common.HardwarePacket BuildReadError() { return HydraProtocolHelper.Build_F5522a_ReadError(); }
        public static Common.HardwarePacket BuildReadFault() { return HydraProtocolHelper.Build_F5522a_ReadFault(); }
        public static Common.HardwarePacket BuildQueryOutput() { return HydraProtocolHelper.Build_F5522a_QueryOutput(); }
        public static Common.HardwarePacket BuildQueryOperate() { return HydraProtocolHelper.Build_F5522a_QueryOperate(); }
        public static Common.HardwarePacket BuildQueryFunction() { return HydraProtocolHelper.Build_F5522a_QueryFunction(); }
        public static Common.HardwarePacket BuildQueryRange() { return HydraProtocolHelper.Build_F5522a_QueryRange(); }

        // ── Safe state changes ───────────────────────────────────────────────────
        public static Common.HardwarePacket BuildReset() { return HydraProtocolHelper.Build_F5522a_Reset(); }
        public static Common.HardwarePacket BuildClearStatus() { return HydraProtocolHelper.Build_F5522a_ClearStatus(); }
        public static Common.HardwarePacket BuildStandby() { return HydraProtocolHelper.Build_F5522a_Standby(); }

        /// <summary>Selects a dc setpoint. The terminals stay disconnected until <see cref="BuildOperate"/>.</summary>
        public static Common.HardwarePacket BuildSetOutput(double amplitude, string unit)
        {
            return HydraProtocolHelper.Build_F5522a_SetOutput(amplitude, unit);
        }

        /// <summary>Selects an ac setpoint. Still does not energise anything on its own.</summary>
        public static Common.HardwarePacket BuildSetOutput(double amplitude, string unit, double hertz)
        {
            return HydraProtocolHelper.Build_F5522a_SetOutput(amplitude, unit, hertz);
        }

        // ── ⚠️ Energises the terminals ───────────────────────────────────────────
        /// <summary>
        /// ⚠️ Puts the selected value on the output terminals for real — up to 1000 V / 20 A. Only for
        /// a commanded calibration target, always paired with <see cref="BuildStandby"/>.
        /// </summary>
        public static Common.HardwarePacket BuildOperate() { return HydraProtocolHelper.Build_F5522a_Operate(); }
    }
}
