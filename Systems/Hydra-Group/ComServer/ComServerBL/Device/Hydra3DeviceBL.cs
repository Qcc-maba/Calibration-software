using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Maba.DAL.BaseDAL;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydaDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.Core.Events;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    class Hydra3DeviceBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Date_Sync = 2;
        public const int STATE_MACHINE__Rate = 3;
        public const int STATE_MACHINE__InitChannels = 4;
        public const int STATE_MACHINE__Logs = 5;
        public const int STATE_MACHINE__Stop = 6;



        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_DateSync { get; private set; }
        public CommonBL.SingleState StateMachine_Rate { get; private set; }
        public CommonBL.SingleState StateMachine_InitChannles { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }
        public CommonBL.SingleState StateMachine_Stop { get; private set; }
        //public CommonBL.SingleState StateMachine_Format { get; private set; }

        #endregion

        #region properties

        //public DeviceMetadata Metadata { get; private set; }
        private MSSqlServer connector = null;
        private List<LogsResponse> responses = new List<LogsResponse>();
        HydraCalculations HC;
        #endregion

        #region ctor

        public Hydra3DeviceBL(Hydra3BLCore parent) : base(parent)
        {
            connector = new MSSqlServer(parent.DeviceSettings.GeneralDBName);
            connector.Open();
            HC = new HydraCalculations(connector);
            HC.Init("21-449");
            //TODO change when UI is ready.
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

            if (this.StateMachine_DateSync == null)
            {
                this.StateMachine_DateSync = new CommonBL.SingleState(STATE_MACHINE__Date_Sync, "Date Sync")
                {
                    Action_DoWork = StateWork__Date_Sync
                };
            }

            if (this.StateMachine_Rate == null)
            {
                this.StateMachine_Rate = new CommonBL.SingleState(STATE_MACHINE__Rate, "Rate")
                {
                    Action_DoWork = StateWork__Rate
                };
            }

            if (this.StateMachine_InitChannles == null)
            {
                this.StateMachine_InitChannles = new CommonBL.SingleState(STATE_MACHINE__InitChannels, "InitChannels")
                {
                    Action_DoWork = StateWork__Init_Channels
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
            this.StateMachine_DateSync.IsActive = true;
            this.StateMachine_Rate.IsActive = true;
            this.StateMachine_InitChannles.IsActive = true;
            this.StateMachine_Logs.IsActive = true;
            //this.StateMachine_Stop.IsActive = false;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_InitSystem,
                this.StateMachine_DateSync,
                this.StateMachine_Rate,
                this.StateMachine_InitChannles,
                this.StateMachine_Logs,
                //this.StateMachine_Stop,
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
                    #region Start Step
                    //moving on from Start step is OK for online device only.
                    //if (this.Metadata != null && this.Metadata.DeviceType != null && this.Metadata.DeviceType.OnlineDevice)
                    //{
                    //    //prepare to routine
                    //    this.StateMachine_IrrigatingValves.IsActive = false;
                    //    this.StateMachine_ReadIO.IsActive = true;

                    //    this.StateMachine_Read_Memory.IsActive = false;
                    //    this.StateMachine_WriteMemory.IsActive = false;
                    return false;
                //}
                #endregion
                //break;
                case DeviceSteps.Close:
                    return true;
            }

            return false;
        }

        public override void OnEvent(DeviceEventArgs e)
        {
            base.OnEvent(e);
            //TODO craete WebClient to onlie - post operation
            //Maba.Connectors.HTTPLibrary.Test for examle of web client post
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
                    req = new InitSystemRequest();
                    req.Packet = Common.HydraProtocolHelper.Build_Reset2Packet();
                    VCT_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new InitSystemRequest();
                    req.Packet = Common.HydraProtocolHelper.BuildDisplayStatPacket();
                    VCT_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req = new InitSystemRequest();
                    req.Packet = Common.HydraProtocolHelper.BuildRoutPacket();
                    VCT_Device.Reset(req);
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
                    request = new GetSetDateRequest();
                    request.Packet = HydraProtocolHelper.Build_SetDate2Packet();
                    this.VCT_Device.SetDate(request);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    request = new GetSetDateRequest();
                    request.Packet = HydraProtocolHelper.Build_SetTime2Packet();
                    this.VCT_Device.SetTime(request);
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
                    req = new RateRequest();
                    req.Packet = Common.HydraProtocolHelper.Build_SetRate2Packet(RateRequest.MeasurementRates.Slow);
                    VCT_Device.Rate(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;

            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }
        #endregion

        #region Init Channels 

        private CommonBL.SingleState.StepWorkResponses StateWork__Init_Channels(CommonBL.SingleState singleState)
        {
            var numberOfChannels = 1;
            InitChannelsRequest req;
            switch (singleState.CurrentStep)
            {
                case 0:
                    for (var i = 0; i < numberOfChannels; i++)
                    {
                        req = new InitChannelsRequest();
                        req.Packet = HydraProtocolHelper.Build_InitChannelsPacket(1, InitChannelsRequest.ThermocoupleTypes.K);
                        VCT_Device.InitChannels(req);
                    }
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new InitChannelsRequest();
                    req.Packet = HydraProtocolHelper.Build_RoutScanPacket(numberOfChannels);
                    VCT_Device.InitChannels(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Logs 

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            LogsRequest req;
            switch (singleState.CurrentStep)
            {
                case 0:
                    req = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ClearLogs2Packet();
                    VCT_Device.GetLogs(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req = new LogsRequest(LogsRequest.LogCommands.LogCount, 1);
                    req.Packet = Common.HydraProtocolHelper.Build_IntervalBetweenScanPacket(req);
                    VCT_Device.GetLogs(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.GetLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ScanIndex();
                    VCT_Device.GetLogs(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3:
                    req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.ClearLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ScanLogs2Packet();
                    VCT_Device.GetLogs(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 4:
                    req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                    req.Packet = Common.HydraProtocolHelper.Build_DataPointPacket();
                    VCT_Device.GetLogs(req, LogResponseCallBack);
                    return CommonBL.SingleState.StepWorkResponses.Wait4Work;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void LogResponseCallBack(LogsResponse response)
        {
            if (response.Result)
            {
                LogsRequest req;
                switch (response.LogCommand)
                {
                    case LogsRequest.LogCommands.LogCount:
                        if (response.LogCount == 0)
                        {
                            req = new LogsRequest(LogsRequest.LogCommands.LogCount);
                            req.Packet = HydraProtocolHelper.Build_DataPointPacket();
                            VCT_Device.GetLogs(req, LogResponseCallBack);
                        }
                        else
                        {
                            for (int i = 0; i < response.LogCount; i++)
                            {
                                req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                                req.Packet = HydraProtocolHelper.Build_DataReadPacket();
                                VCT_Device.GetLogs(req, LogResponseCallBack);
                            }

                            req = new LogsRequest(LogsRequest.LogCommands.LogCount);
                            req.Packet = HydraProtocolHelper.Build_DataPointPacket();
                            VCT_Device.GetLogs(req, LogResponseCallBack);
                        }
                        break;

                    case LogsRequest.LogCommands.GetLogs:
                        HandelLogs(response);

                        req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                        req.Packet = HydraProtocolHelper.Build_DataPointPacket();
                        VCT_Device.GetLogs(req, LogResponseCallBack);

                        req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                        req.Packet = HydraProtocolHelper.Build_DataReadPacket();
                        VCT_Device.GetLogs(req, LogResponseCallBack);
                        break;
                    case LogsRequest.LogCommands.StartScan:
                        if (response.LogCount == 0)
                        {
                            req = new LogsRequest(LogsRequest.LogCommands.StartScan);
                            req.Packet = HydraProtocolHelper.Build_ID_Packet();
                            VCT_Device.GetLogs(req, LogResponseCallBack);
                            req.Packet = HydraProtocolHelper.Build_DataPointPacket();
                            VCT_Device.GetLogs(req, LogResponseCallBack);
                        }
                        break;
                }
            }
            else
            {
                throw new Exception();
            }
        }



        #endregion

        #region Private Methods

        private void HandelLogs(LogsResponse response)
        {
            //TODO  from DB.
            bool flagType = true;
            foreach (var item in response.Mesurements)
            {
                Console.WriteLine("The Value is: " + item);
            }
            responses.Add(response);
            if (flagType)
            {
                var results = HC.CalcCalibrationDeviationForTemperature(response);
            }
            else
            {
                double result = HC.CalcCalibrationDeviationForTemperatureAndHumidity(response);
            }
        }

        #endregion

        #endregion
    }
}
