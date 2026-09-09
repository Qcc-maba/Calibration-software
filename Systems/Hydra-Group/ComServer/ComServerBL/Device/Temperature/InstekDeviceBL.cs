using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydaDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.BL.HydaDevices.Device
{
    public class InstekDeviceBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__Channels = 1;
        public const int STATE_MACHINE__Logs = 2;

        public CommonBL.SingleState StateMachine_Logs { get; private set; }
        public CommonBL.SingleState StateMachine_InitChannels { get; private set; }

        #endregion

        #region properties
        private HydraCalculations HC;
        private HardwareBL_Settings settings;

        #endregion

        #region ctor

        public InstekDeviceBL(InstekBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;
            HC = new HydraCalculations(new ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository());
        }



        #endregion

        #region overridden from CommonBL.BaseBLDevice

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            HC.Init(settings.Instek.Masters).GetAwaiter().GetResult();

            if (this.StateMachine_Logs == null)
            {
                this.StateMachine_Logs = new CommonBL.SingleState(STATE_MACHINE__Logs, "Logs")
                {
                    Action_DoWork = StateWork__Logs
                };
            }
            this.StateMachine_Logs.IsActive = true;

            if (this.StateMachine_InitChannels == null)
            {
                this.StateMachine_InitChannels = new CommonBL.SingleState(STATE_MACHINE__Channels, "Init Channels")
                {
                    Action_DoWork = StateWork__Init_Channels
                };
            }
            this.StateMachine_InitChannels.IsActive = true;
            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_Logs,
                this.StateMachine_InitChannels
            };

            return states
                        .OrderBy(s => s.State)
                        .ToArray();

        }

        protected override bool OnStepStart(DeviceSteps step)
        {
            switch (step)
            {
                case DeviceSteps.Start:
                    return true;
                case DeviceSteps.Routine:
                    //this.StateMachine_Logs.IsActive = true;
                    this.StateMachine_InitChannels.IsActive = false;

                    return true;
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

        #region private methods :: StateMachines

        #region Init system
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            InitSystemRequest req;

            switch (singleState.CurrentStep)
            {
                case 0:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_OptidewGetDewpoint()
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_OptidewGetTemperature()
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;

            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Date & Time Sync

        private CommonBL.SingleState.StepWorkResponses StateWork__Date_Sync(CommonBL.SingleState singleState)
        {
            GetSetDateRequest request;
            switch (singleState.CurrentStep)
            {
                case 0:
                    request = new GetSetDateRequest
                    {
                        Packet = HydraProtocolHelper.Build_SetDate2Packet()
                    };
                    this.HW_Device.SetDate(request);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    request = new GetSetDateRequest
                    {
                        Packet = HydraProtocolHelper.Build_SetTime2Packet()
                    };
                    this.HW_Device.SetTime(request);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Rate

        private CommonBL.SingleState.StepWorkResponses StateWork__Rate(CommonBL.SingleState singleState)
        {
            RateRequest req;
            switch (singleState.CurrentStep)
            {
                case 0:
                    req = new RateRequest
                    {
                        Packet = HydraProtocolHelper.Build_SetRate2Packet(settings.Hydra3type.MeasurementRate)
                    };
                    HW_Device.Rate(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;

            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }
        #endregion

        #region Init Channels 

        private CommonBL.SingleState.StepWorkResponses StateWork__Init_Channels(CommonBL.SingleState singleState)
        {
            InitSystemRequest req;
            switch (singleState.CurrentStep)
            {
                case 0:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekReset()
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.buildClearBuffer()
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekRout()
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekConf(settings.Instek)
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 4:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekScan(settings.Instek.Channels)
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 5:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekTrigSoruce()
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 6:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekScanInterval(settings.Instek.Interval)
                    };
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 7:
                    req = new InitSystemRequest
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekTrigerCount()
                    };
                    HW_Device.Reset(req);

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Logs 

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            LogsRequest req = null;
            switch (singleState.CurrentStep)
            {
                case 0:
                    req = new LogsRequest(LogsRequest.LogCommands.GetLogs)
                    {
                        Packet = Common.HydraProtocolHelper.Build_InstekRead(settings.Instek.Sensor.MeasureType, settings.Instek.Channels)
                    };
                    HW_Device.GetLogs(req, LogResponseCallBack);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void LogResponseCallBack(LogsResponse response)
        {
            if (response.HasResponse)
            {
                // NOTE: the success path is not implemented for Instek — the reading is received but
                // never passed to HandelLogs(response), so no measurement is produced or broadcast.
                // (Previously this was a block of commented-out code, which hid the gap.)
                // Wire up HandelLogs + the follow-up READ? here when an Instek unit is available to test against.
            }
            else
            {
                Libs.Trace.Tracer.Error("Error in Logs");
            }
        }



        #endregion

        #endregion

        #region Private Methods

        private void HandelLogs(LogsResponse response)
        {
            /* Tuple<double, int>
             * Double- Value.
             * Int- status.
             * 0- OK
             * 1- Low Value
             * 2- High Value
             * 3- Wrong value
             * */

            HC.ProcessResults(response, settings.Instek);

        }
        #endregion

    }
}
