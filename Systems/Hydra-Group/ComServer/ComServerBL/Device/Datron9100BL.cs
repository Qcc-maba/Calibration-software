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
    /// ⚠️ SCAFFOLD — the exact 9100 command set is NOT yet confirmed. Every command string lives in the
    /// single <see cref="Datron9100Commands"/> table below and currently holds a generic IEEE-488.2
    /// placeholder (*RST / *CLS / SYST:REM / READ?). The 9100 is an old instrument and may not support
    /// them. When the 9100 programming manual is available, edit ONLY that table — the state machine
    /// here iterates it generically and needs no change. Do NOT invent Datron mnemonics.
    /// </para>
    /// <para>
    /// Cannot be verified against hardware until NI-488.2 is installed (adapter is currently in
    /// Device-Manager error Code 28). See docs/devices/Datron-9100/integration-checklist.md.
    /// </para>
    /// </summary>
    public class Datron9100BL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        // TODO(manual): confirm the 9100 over-range / open-circuit sentinel and its exact value.
        // IEEE-488.2 instruments commonly report 9.9e37; kept here as a placeholder guard.
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
                    // TODO(manual): confirm the 9100 reply format and whether the reported value is a
                    // measurement or an echoed setpoint (this device is a SOURCE). Adjust parsing/units
                    // in the parser/calculator, not here, once the format is known.
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

    /// <summary>
    /// The single source of truth for every command string the Datron 9100 BL sends.
    /// <para>
    /// ⚠️ ALL ENTRIES ARE PLACEHOLDERS (generic IEEE-488.2 via <see cref="HydraProtocolHelper"/>). When
    /// the 9100 programming manual is available, replace each <c>Build</c> delegate with the real 9100
    /// command and update the init sequence order. This is the ONLY place command strings should be
    /// edited for this device. Do NOT fabricate Datron mnemonics — transcribe them from the manual.
    /// </para>
    /// </summary>
    public static class Datron9100Commands
    {
        /// <summary>One labelled init command: a human-readable purpose plus the packet it builds.</summary>
        public sealed class InitCommand
        {
            /// <summary>What this step is meant to achieve (kept for logs and for the manual drop-in).</summary>
            public string Purpose { get; private set; }

            /// <summary>Builds the wire packet. Swap this delegate for the real 9100 command.</summary>
            public Func<Common.HardwarePacket> Build { get; private set; }

            public InitCommand(string purpose, Func<Common.HardwarePacket> build)
            {
                Purpose = purpose;
                Build = build;
            }
        }

        /// <summary>
        /// Ordered init sequence, one command per state-machine step. Edit/reorder freely — the state
        /// machine iterates this array by index.
        /// </summary>
        public static readonly InitCommand[] InitSequence =
        {
            // TODO(manual): 9100 reset. Placeholder: generic *RST.
            new InitCommand("reset", () => HydraProtocolHelper.Build_ResetPacket(false)),

            // TODO(manual): 9100 clear-status / clear-buffer. Placeholder: generic *CLS.
            new InitCommand("clear status", () => HydraProtocolHelper.buildClearBuffer()),

            // TODO(manual): 9100 go-to-remote. Placeholder: generic SYST:REM.
            new InitCommand("remote", () => HydraProtocolHelper.Build_RemotePacket()),

            // TODO(manual): add the real 9100 output/setpoint/range configuration steps here.
        };

        /// <summary>
        /// The value-read query issued in a loop by the Read state.
        /// TODO(manual): replace with the real 9100 output/measure query. Placeholder: generic READ?.
        /// </summary>
        public static Common.HardwarePacket BuildReadValue()
        {
            return HydraProtocolHelper.Build_ReadValue();
        }
    }
}
