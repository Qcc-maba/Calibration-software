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
    /// Pendulum CNT-90 timer/counter/analyzer over GPIB (SCPI, native command set).
    /// Verified live 2026-09-01 against "PENDULUM, CNT-90, 938636, V1.14 28 Jun 2006" at address 7.
    /// <para>
    /// Init: *RST -> *CLS -> :SYSTem:LANGuage NATive -> :FORMat ASCii -> :SYSTem:TOUT ON ->
    /// :SYSTem:TOUT:TIME -> :SYSTem:TOUT:AUTO ON -> :CONFigure:FREQuency for the first input.
    /// </para>
    /// <para>
    /// ⚠️ Acquisition is guarded, and that guard is the whole point of this class. With nothing
    /// connected to the input, a frequency measurement on this counter BLOCKS - it waits for edges
    /// that never arrive and, unlike an oscilloscope, returns no sentinel (the documented 9.91E37
    /// exists only in 53131/53132 emulation mode, and :SYSTem:TOUT was observed not to release the
    /// query). Each cycle therefore asks for the input's peak voltage first - a question the counter
    /// always answers quickly - and only commits to a frequency query when that says a signal is
    /// actually present.
    /// </para>
    /// See docs/devices/electronics/Pendulum-CNT-90/protocol.md.
    /// </summary>
    public class Cnt90BL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Logs = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }

        /// <summary>Measurement timeout armed at init, in seconds.</summary>
        private const double MeasurementTimeoutSeconds = 1.0;

        /// <summary>Stop re-queueing after this many consecutive failed reads (resumes on reconnect).</summary>
        private const int MaxConsecutiveFailures = 10;

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;

        /// <summary>The measurement inputs to acquire, validated against what this model has.</summary>
        private readonly List<int> channels;

        /// <summary>Round-robin cursor into <see cref="channels"/>.</summary>
        private int _channelIndex;

        private int _consecutiveFailures;

        /// <summary>
        /// True while the outstanding request is the cheap signal-presence probe rather than the
        /// frequency query, so the reply is interpreted as a voltage and not broadcast as a reading.
        /// </summary>
        private bool _awaitingSignalProbe;

        #endregion

        #region ctor

        public Cnt90BL(Cnt90BLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;

            var configured = settings.Cnt90 != null ? settings.Cnt90.Channels : null;
            channels = configured != null
                ? configured.Where(Cnt90Readings.IsValidChannel).Distinct().OrderBy(c => c).ToList()
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
                case 0: // *RST - known state. Note it also leaves the measurement timeout OFF.
                    req.Packet = HydraProtocolHelper.Build_Cnt90_Reset();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1: // *CLS
                    req.Packet = HydraProtocolHelper.Build_Cnt90_ClearStatus();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2: // Force the documented command set, in case the unit was left emulating a 53131.
                    req.Packet = HydraProtocolHelper.Build_Cnt90_SelectNativeLanguage();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3: // ASCII replies, so the shared parser sees text and not a binary block.
                    req.Packet = HydraProtocolHelper.Build_Cnt90_FormatAscii();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 4: // *RST leaves the measurement timeout off - arm it.
                    req.Packet = HydraProtocolHelper.Build_Cnt90_TimeoutOn();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 5:
                    req.Packet = HydraProtocolHelper.Build_Cnt90_TimeoutTime(MeasurementTimeoutSeconds);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 6: // Short timeout to the first start trigger - "is there any signal at all?".
                    req.Packet = HydraProtocolHelper.Build_Cnt90_TimeoutAuto();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 7:
                    req.Packet = HydraProtocolHelper.Build_Cnt90_ConfigureFrequency(channels[0]);
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
            req.Packet = HydraProtocolHelper.Build_Cnt90_MeasureVoltageMax(channel);
            HW_Device.GetLogs(req, MeasurementCallback);
        }

        private void QueueFrequencyRead(int channel)
        {
            _awaitingSignalProbe = false;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_Cnt90_MeasureFrequency(channel);
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
                // No reply at all - a transport timeout, or the frequency query blocked and the layer
                // gave up on it. Either way count it and move on to the next input.
                _consecutiveFailures++;
                AdvanceChannelAndProbe();
                return;
            }

            var raw = response.Measurements[0];

            if (wasProbe)
            {
                if (Cnt90Readings.IndicatesSignalPresent(raw))
                {
                    // Something is on the input - now the frequency query is safe to issue.
                    QueueFrequencyRead(channel);
                }
                else
                {
                    Libs.Trace.Tracer.Info(
                        "[CNT-90] {0} input {1}: no signal ({2:G4} V peak) - skipping the frequency query, which would block.",
                        HW_Device.SN, channel, raw);
                    AdvanceChannelAndProbe();
                }
                return;
            }

            if (Cnt90Readings.IsNoResult(raw))
            {
                Libs.Trace.Tracer.Info("[CNT-90] {0} input {1}: no valid result.", HW_Device.SN, channel);
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
                    "[CNT-90] {0} consecutive failed reads on {1} - stopping acquisition until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            _channelIndex = (_channelIndex + 1) % channels.Count;
            QueueSignalProbe(channels[_channelIndex]);
        }

        #endregion
    }
}
