using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydaDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydaDevices.Device
{
    public class OptidewDeviceBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__Logs = 1;

        public CommonBL.SingleState StateMachine_Logs { get; private set; }
        //public CommonBL.SingleState StateMachine_Stop { get; private set; }

        #endregion

        #region properties
        private HydraCalculations HC;
        private HardwareBL_Settings settings;

        #endregion

        #region ctor

        public OptidewDeviceBL(OptidewBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;
            HC = new HydraCalculations(new ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository());
        }



        #endregion

        #region overridden from CommonBL.BaseBLDevice

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            HC.Init(settings.Optidew.Masters).GetAwaiter().GetResult();

            if (this.StateMachine_Logs == null)
            {
                this.StateMachine_Logs = new CommonBL.SingleState(STATE_MACHINE__Logs, "Logs")
                {
                    Action_DoWork = StateWork__Logs
                };
            }
            this.StateMachine_Logs.IsActive = true;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_Logs,
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
                    this.StateMachine_Logs.IsActive = true;
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
            InitChannelsRequest req;
            switch (singleState.CurrentStep)
            {
                case 0:
                    for (var i = 0; i < settings.Hydra3type.Channels.Count; i++)
                    {
                        req = new InitChannelsRequest
                        {
                            Packet = HydraProtocolHelper.Build_InitChannelsPacket(settings.Hydra3type.Channels[i], settings.Hydra3type)
                        };
                        HW_Device.InitChannels(req);
                    }
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new InitChannelsRequest
                    {
                        Packet = HydraProtocolHelper.Build_RoutScanPacket(settings.Hydra3type.Channels)
                    };
                    HW_Device.InitChannels(req);
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
                        Packet = Common.HydraProtocolHelper.Build_OptidewGetTemperature()
                    };
                    HW_Device.GetLogs(req, LogResponseCallBack);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new LogsRequest(LogsRequest.LogCommands.GetLogs)
                    {
                        Packet = Common.HydraProtocolHelper.Build_OptidewGetDewpoint()
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
                LogsRequest req;
                HandelLogs(response);


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

            HC.ProcessResults(response, settings.Optidew);

        }
        #endregion

    }
}
