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
    /// PRODIGIT 3111 DC electronic load (80 V / 70 A / 350 W) over RS-232.
    /// Mapped live 2026-09-02 on COM10 at 115200 8-N-1; *IDN? answers the bare token "PRODIGIT_3111".
    /// <para>
    /// ⚠️ This instrument SINKS current from whatever is wired to its input. The BL is
    /// <b>read-only</b>: it identifies the unit, reports whether the load is armed, and polls the
    /// measurement the family is configured for. It never arms the load, never changes a setpoint,
    /// and no command that could do either is even built (see the PRODIGIT region in
    /// <see cref="HydraProtocolHelper"/>).
    /// </para>
    /// <para>
    /// The instrument has no usable error channel: <c>SYST:ERR?</c> is silent and <c>ERR?</c> answers
    /// a constant. Silence is the only failure signal, so a missing reply is counted and acquisition
    /// stops after enough of them rather than being retried forever.
    /// </para>
    /// See docs/devices/electronics/Prodigit-3111/protocol.md.
    /// </summary>
    public class Prodigit3111BL : CommonBL.BaseBLDevice
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
        private int _consecutiveFailures;

        /// <summary>True while the outstanding request is the LOAD? state query, not a measurement.</summary>
        private bool _awaitingLoadState;

        #endregion

        #region ctor

        public Prodigit3111BL(Prodigit3111BLCore parent) : base(parent)
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

        #region state machine :: InitSystem (read-only)

        /// <summary>
        /// Read-only init. There is deliberately no *RST here: this load has no documented reset, and
        /// on an instrument that sinks current a blind reset is not something to send speculatively.
        /// </summary>
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var req = new InitSystemRequest();

            switch (singleState.CurrentStep)
            {
                case 0:
                    req.Packet = HydraProtocolHelper.Build_Prodigit_Version();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Logs

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    QueueLoadStateQuery();
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>
        /// Asks whether the load is armed. Purely observational - it tells the log (and anyone reading
        /// it) whether the measurements that follow are of a loaded or an idle input.
        /// </summary>
        private void QueueLoadStateQuery()
        {
            _awaitingLoadState = true;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_Prodigit_QueryLoadState();
            HW_Device.GetLogs(req, ReadCallback);
        }

        private void QueueMeasurement()
        {
            _awaitingLoadState = false;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = HydraProtocolHelper.Build_Prodigit_Measure(
                settings.Prodigit3111 != null ? settings.Prodigit3111.Sensor : null);
            HW_Device.GetLogs(req, ReadCallback);
        }

        private void ReadCallback(LogsResponse response)
        {
            var wasLoadState = _awaitingLoadState;

            // Parsed here rather than from response.Measurements: "LOAD?" answers a bare "0", which
            // none of the shared numeric branches recognise as a measurement. Prodigit3111Readings
            // owns the interpretation for this instrument.
            var reply = response != null && response.Result ? response.RawText : null;

            double raw;
            if (!Prodigit3111Readings.TryParseMeasurement(reply, out raw))
            {
                _consecutiveFailures++;
                Continue();
                return;
            }

            if (wasLoadState)
            {
                // Observational only: the BL reports the state, it never changes it.
                Libs.Trace.Tracer.Info("[PRODIGIT 3111] {0}: load input is {1}.",
                    HW_Device.SN, Prodigit3111Readings.IsLoadOn(reply) ? "ARMED" : "off");
                QueueMeasurement();
                return;
            }

            var sensor = settings.Prodigit3111 != null ? settings.Prodigit3111.Sensor : null;
            var rated = Prodigit3111Readings.RatedMaximumFor(sensor);

            if (Prodigit3111Readings.IsPlausible(raw, rated))
            {
                _consecutiveFailures = 0;
                HW_Device.BroadcastAllMeasurements(
                    new List<int> { Prodigit3111Readings.MeasurementChannel },
                    new List<double> { raw });
            }
            else
            {
                Libs.Trace.Tracer.Info("[PRODIGIT 3111] {0}: reading {1:G6} is outside the rated {2:G6} - discarded.",
                    HW_Device.SN, raw, rated);
                _consecutiveFailures++;
            }

            Continue();
        }

        /// <summary>
        /// Starts the next cycle. A single bad read must not stop acquisition, but we stop
        /// re-queueing once the device is gone or keeps failing - with no error channel on this
        /// instrument, a run of silences is the only signal that something is wrong.
        /// </summary>
        private void Continue()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[PRODIGIT 3111] {0} consecutive failed reads on {1} - stopping acquisition until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            QueueLoadStateQuery();
        }

        #endregion
    }
}
