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
    /// ⚠️ SCAFFOLD — the exact 9100 command set is NOT yet confirmed. The init/read commands below use
    /// generic IEEE-488.2 placeholders (*RST / *CLS / SYST:REM / READ?); replace them with the real
    /// Datron commands from the 9100 programming manual (see docs/devices/Datron-9100/). Cannot be
    /// verified against hardware until NI-488.2 is installed (adapter is currently in Device-Manager
    /// error Code 28).
    /// </para>
    /// </summary>
    public class Datron9100BL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        // 9100 over-range / open sentinel — confirm against the manual.
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

        #region state machine :: InitSystem (TODO: confirm 9100 commands from the manual)

        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var req = new InitSystemRequest();
            switch (singleState.CurrentStep)
            {
                case 0: // reset — 9100 equivalent TBD
                    req.Packet = Common.HydraProtocolHelper.Build_ResetPacket(false);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1: // clear status — 9100 equivalent TBD
                    req.Packet = Common.HydraProtocolHelper.buildClearBuffer();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2: // remote — 9100 equivalent TBD
                    req.Packet = Common.HydraProtocolHelper.Build_RemotePacket();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Read (TODO: confirm the 9100 output/measure query from the manual)

        private CommonBL.SingleState.StepWorkResponses StateWork__Read(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ReadValue(); // placeholder "READ?"
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
                // Continuous read, self-recovering; stop if the device is gone or keeps failing.
                if (HW_Device != null && HW_Device.IsConnected && _consecutiveFailures < MaxConsecutiveFailures)
                {
                    var next = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                    next.Packet = Common.HydraProtocolHelper.Build_ReadValue();
                    HW_Device.GetLogs(next, ReadValueCallback);
                }
            }
        }

        #endregion
    }
}
