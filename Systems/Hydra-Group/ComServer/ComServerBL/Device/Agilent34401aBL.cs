using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Agilent/Keysight 34401A digital multimeter over RS-232 (SCPI).
    /// Verified protocol (2026-07-16, fw 10-5-2): 9600 8-N-1, DTR/DSR, "\r\n".
    /// Sequence: *RST -> *CLS -> SYST:REM (mandatory) -> CONF:&lt;func&gt; -> &lt;func&gt;:RANG:AUTO ON -> READ? loop.
    /// READ? returns a scientific-notation value; 9.9E37 = over-range / open.
    /// See docs/devices/Agilent-34401A/protocol.md.
    /// </summary>
    public class Agilent34401aBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Logs = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }
        #endregion

        #region properties

        private readonly HydraCalculations HC;
        private readonly HardwareBL_Settings settings;

        /// <summary>Consecutive failed/empty READ? responses; reset on every good reading.</summary>
        private int _consecutiveFailures;

        /// <summary>Stop re-queueing after this many consecutive failures (resumes on reconnect).</summary>
        private const int MaxConsecutiveFailures = 10;
        #endregion

        #region ctor

        public Agilent34401aBL(Agilent34401aBLCore parent) : base(parent)
        {
            HC = new HydraCalculations(new ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository());
            settings = parent.DeviceSettings;
        }

        #endregion

        #region overridden from CommonBL.BaseBLDevice

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            HC.Init(settings.Agilent.Masters).GetAwaiter().GetResult();

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

        #region state machine :: InitSystem (verified 34401A sequence)

        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var req = new InitSystemRequest();

            switch (singleState.CurrentStep)
            {
                case 0: // *RST
                    req.Packet = Common.HydraProtocolHelper.Build_ResetPacket(false);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1: // *CLS
                    req.Packet = Common.HydraProtocolHelper.buildClearBuffer();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2: // SYST:REM — mandatory over RS-232 (else error 550 "Command not allowed in local")
                    req.Packet = Common.HydraProtocolHelper.Build_RemotePacket();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3: // CONF:<func>  (VOLT:DC / RES / FRES per settings.Agilent.Sensor)
                    req.Packet = Common.HydraProtocolHelper.Build_Configuration(settings.Agilent.Sensor);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 4: // <func>:RANG:AUTO ON
                    req.Packet = Common.HydraProtocolHelper.Build_AutoRange(settings.Agilent.Sensor);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Logs (READ? acquisition loop)

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ReadValue(); // "READ?"
                    HW_Device.GetLogs(req, ReadValueCallback);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void ReadValueCallback(LogsResponse response)
        {
            try
            {
                // Only broadcast a genuine reading: a successful response that carries a value which
                // is not the 34401A over-range / open sentinel (empty responses must not become 0).
                if (response != null && response.Result &&
                    response.Measurements != null && response.Measurements.Count > 0)
                {
                    _consecutiveFailures = 0;
                    var raw = response.Measurements[0];
                    if (!Agilent34401aReadings.IsOverload(raw))
                    {
                        var value = raw;
                        var sensor = settings.Agilent.Sensor;

                        // RTD/FRTD: convert the measured resistance to temperature (°C) via the master's curve.
                        if (Agilent34401aReadings.RequiresTemperatureConversion(sensor))
                        {
                            var masterId = settings.Agilent.Masters.FirstOrDefault();
                            value = HC.CalcConversionUnits(raw, HydraCalculations.ConversionUnits.Ohm,
                                                           HydraCalculations.ConversionUnits.Celsius, masterId).Item1;
                        }

                        HW_Device.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { value });
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
        /// Queues the next READ?. A single bad/empty read (or an overload) must not stop acquisition,
        /// but we stop re-queueing once the device is gone or keeps failing — otherwise the callback
        /// chain would pile unbounded requests onto a disconnected instrument's queue.
        /// </summary>
        private void RequestNextReading()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[34401A] {0} consecutive failed reads on {1} - stopping acquisition until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            var next = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            next.Packet = Common.HydraProtocolHelper.Build_ReadValue();
            HW_Device.GetLogs(next, ReadValueCallback);
        }

        #endregion
    }
}
