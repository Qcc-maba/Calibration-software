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
    /// Keysight InfiniiVision EDUX1002A oscilloscope (1000 X-Series, 50 MHz, 2 analog channels), SCPI.
    /// <para>
    /// Init: *RST -> *CLS -> :TIMebase:MODE MAIN -> :CHANnel&lt;n&gt;:DISPlay 1 per configured channel
    /// -> :AUToscale -> :RUN. Acquisition then round-robins one :MEASure? query per channel, each
    /// carrying an explicit source so a reply can never be attributed to the wrong channel.
    /// </para>
    /// <para>
    /// A measurement the scope cannot make answers +9.9E+37; that sentinel is dropped rather than
    /// broadcast (see <see cref="KeysightEdux1002aReadings"/>).
    /// </para>
    /// <para>
    /// Unlike the other instruments here the scope applies no master correction curve - it reads the
    /// signal under test directly - so no <c>HydraCalculations</c> conversion is performed.
    /// </para>
    /// See docs/devices/electronics/Keysight-EDUX1002A/protocol.md.
    /// </summary>
    public class KeysightEdux1002aBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Logs = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }

        /// <summary>Fixed init steps (*RST, *CLS, :TIMebase:MODE MAIN) issued before the per-channel ones.</summary>
        private const int InitPrologueSteps = 3;

        /// <summary>Stop re-queueing after this many consecutive failed reads (resumes on reconnect).</summary>
        private const int MaxConsecutiveFailures = 10;

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;

        /// <summary>The analog channels to acquire, validated against what this model actually has.</summary>
        private readonly List<int> channels;

        /// <summary>Round-robin cursor into <see cref="channels"/>.</summary>
        private int _channelIndex;

        /// <summary>Consecutive failed/empty measurement replies; reset on every good reading.</summary>
        private int _consecutiveFailures;

        #endregion

        #region ctor

        public KeysightEdux1002aBL(KeysightEdux1002aBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;

            var configured = settings.Edux1002a != null ? settings.Edux1002a.Channels : null;
            channels = configured != null
                ? configured.Where(KeysightEdux1002aReadings.IsValidChannel).Distinct().OrderBy(c => c).ToList()
                : new List<int>();

            // A scope with no usable channel configured would otherwise never measure anything.
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
                case DeviceSteps.Start:
                    return true;
                case DeviceSteps.Routine:
                    return false;
                case DeviceSteps.Close:
                    return true;
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
            var step = singleState.CurrentStep;

            switch (step)
            {
                case 0: // *RST - known state (CH1 on, main timebase)
                    req.Packet = HydraProtocolHelper.Build_Edux1002a_Reset();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1: // *CLS
                    req.Packet = HydraProtocolHelper.Build_Edux1002a_ClearStatus();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2: // :TIMebase:MODE MAIN - measurements are taken over the main sweep
                    req.Packet = HydraProtocolHelper.Build_Edux1002a_TimebaseMain();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            // Then one :CHANnel<n>:DISPlay 1 per configured channel - an undisplayed channel is not
            // measurable - followed by :AUToscale and :RUN.
            var offset = step - InitPrologueSteps;

            if (offset < channels.Count)
            {
                req.Packet = HydraProtocolHelper.Build_Edux1002a_ChannelDisplay(channels[offset], true);
                HW_Device.Reset(req);
                return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            if (offset == channels.Count)
            {
                req.Packet = HydraProtocolHelper.Build_Edux1002a_AutoScale();
                HW_Device.Reset(req);
                return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            if (offset == channels.Count + 1)
            {
                req.Packet = HydraProtocolHelper.Build_Edux1002a_Run();
                HW_Device.Reset(req);
                return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Logs (:MEASure? acquisition loop)

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    _channelIndex = 0;
                    QueueMeasurement(channels[_channelIndex]);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void QueueMeasurement(int channel)
        {
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_Edux1002a_Measure(
                settings.Edux1002a != null ? settings.Edux1002a.Sensor : null, channel);
            HW_Device.GetLogs(req, MeasurementCallback);
        }

        private void MeasurementCallback(LogsResponse response)
        {
            // The reply belongs to the channel we last asked about; advance only after handling it.
            var channel = channels[_channelIndex];

            try
            {
                if (response != null && response.Result &&
                    response.Measurements != null && response.Measurements.Count > 0)
                {
                    var raw = response.Measurements[0];
                    if (KeysightEdux1002aReadings.IsMeasurementError(raw))
                    {
                        // Not a transport failure: the waveform simply is not on screen. Keep polling,
                        // but never broadcast the +9.9E+37 sentinel as if it were a reading.
                        Libs.Trace.Tracer.Info(
                            "[EDUX1002A] {0} CH{1}: measurement unavailable (waveform not displayed).",
                            HW_Device.SN, channel);
                    }
                    else
                    {
                        _consecutiveFailures = 0;
                        HW_Device.BroadcastAllMeasurements(new List<int> { channel }, new List<double> { raw });
                    }
                }
                else
                {
                    _consecutiveFailures++;
                }
            }
            finally
            {
                RequestNextReading();
            }
        }

        /// <summary>
        /// Queues the next channel's :MEASure? query. A single bad read must not stop acquisition,
        /// but we stop re-queueing once the device is gone or keeps failing - otherwise the callback
        /// chain would pile unbounded requests onto a disconnected instrument's queue.
        /// </summary>
        private void RequestNextReading()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[EDUX1002A] {0} consecutive failed reads on {1} - stopping acquisition until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            _channelIndex = (_channelIndex + 1) % channels.Count;
            QueueMeasurement(channels[_channelIndex]);
        }

        #endregion
    }
}
