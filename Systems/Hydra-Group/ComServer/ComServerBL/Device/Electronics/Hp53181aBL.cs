using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// HP 53181A frequency counter over GPIB (SCPI 1992.0).
    /// Verified live 2026-09-02 against "HEWLETT-PACKARD,53181A,0,3703" at GPIB address 3.
    /// <para>
    /// ⚠️ Acquisition is guarded, for the same reason <see cref="Cnt90BL"/> is: with nothing on the
    /// input a frequency measurement BLOCKS - it waits for edges that never arrive and returns
    /// nothing at all (measured: no reply after 10 s). A voltage measurement answers in well under a
    /// second whatever is connected, so each cycle asks that first and only commits to a frequency
    /// query when a signal is actually present.
    /// </para>
    /// <para>
    /// Unlike the CNT-90 this counter has a real SCPI error queue, so the init drains it and the BL
    /// can tell a rejected command from a silent one.
    /// </para>
    /// See docs/devices/electronics/HP-53181A/protocol.md.
    /// </summary>
    public class Hp53181aBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Logs = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }

        private const int MaxConsecutiveFailures = 10;

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;
        private readonly List<int> channels;

        private int _channelIndex;
        private int _consecutiveFailures;

        /// <summary>True while the outstanding request is the signal-presence probe, not a frequency read.</summary>
        private bool _awaitingSignalProbe;

        #endregion

        #region ctor

        public Hp53181aBL(Hp53181aBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;

            var configured = settings.Hp53181a != null ? settings.Hp53181a.Channels : null;
            channels = configured != null
                ? configured.Where(Hp53181aReadings.IsValidChannel).Distinct().OrderBy(c => c).ToList()
                : new List<int>();

            if (channels.Count == 0)
                channels.Add(1);
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

            if (this.StateMachine_Logs == null)
            {
                this.StateMachine_Logs = new CommonBL.SingleState(STATE_MACHINE__Logs, "Logs")
                {
                    Action_DoWork = StateWork__Logs
                };
            }

            this.StateMachine_InitSystem.IsActive = true;
            this.StateMachine_Logs.IsActive = true;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_InitSystem,
                this.StateMachine_Logs,
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

        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var req = new InitSystemRequest();

            switch (singleState.CurrentStep)
            {
                case 0: // *RST - known state: FUNC "FREQ", 1 MOhm AC-coupled input, immediate arming.
                    req.Packet = HydraProtocolHelper.Build_Hp53181a_Reset();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1: // *CLS - drain the status and error registers.
                    req.Packet = HydraProtocolHelper.Build_Hp53181a_ClearStatus();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req.Packet = HydraProtocolHelper.Build_Hp53181a_ConfigureFrequency(channels[0]);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Logs (guarded acquisition loop)

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    _channelIndex = 0;
                    QueueSignalProbe(channels[_channelIndex]);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>
        /// Asks for the input's peak voltage. This is the guard: it always answers, so it tells us
        /// whether committing to a (potentially blocking) frequency query is safe.
        /// </summary>
        private void QueueSignalProbe(int channel)
        {
            _awaitingSignalProbe = true;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_Hp53181a_MeasureVoltageMax(channel);
            HW_Device.GetLogs(req, MeasurementCallback);
        }

        private void QueueFrequencyRead(int channel)
        {
            _awaitingSignalProbe = false;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_Hp53181a_MeasureFrequency(channel);
            HW_Device.GetLogs(req, MeasurementCallback);
        }

        private void MeasurementCallback(LogsResponse response)
        {
            var channel = channels[_channelIndex];
            var wasProbe = _awaitingSignalProbe;
            var haveValue = response != null && response.Result &&
                            response.Measurements != null && response.Measurements.Count > 0;

            if (!haveValue)
            {
                // No reply: a transport timeout, or a frequency query that blocked and was abandoned.
                _consecutiveFailures++;
                AdvanceChannelAndProbe();
                return;
            }

            var raw = response.Measurements[0];

            if (wasProbe)
            {
                if (Hp53181aReadings.IndicatesSignalPresent(raw))
                {
                    QueueFrequencyRead(channel);
                }
                else
                {
                    Libs.Trace.Tracer.Info(
                        "[HP 53181A] {0} input {1}: no signal ({2:G4} V peak) - skipping the frequency query, which would block.",
                        HW_Device.SN, channel, raw);
                    AdvanceChannelAndProbe();
                }
                return;
            }

            if (Hp53181aReadings.IsNoResult(raw))
            {
                Libs.Trace.Tracer.Info("[HP 53181A] {0} input {1}: no valid result.", HW_Device.SN, channel);
            }
            else
            {
                _consecutiveFailures = 0;
                HW_Device.BroadcastAllMeasurements(new List<int> { channel }, new List<double> { raw });
            }

            AdvanceChannelAndProbe();
        }

        /// <summary>
        /// Moves to the next configured input and probes it. A single bad read must not stop
        /// acquisition, but we stop re-queueing once the device is gone or keeps failing - otherwise
        /// the callback chain would pile unbounded requests onto a disconnected instrument's queue.
        /// </summary>
        private void AdvanceChannelAndProbe()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[HP 53181A] {0} consecutive failed reads on {1} - stopping acquisition until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            _channelIndex = (_channelIndex + 1) % channels.Count;
            QueueSignalProbe(channels[_channelIndex]);
        }

        #endregion
    }
}
