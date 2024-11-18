using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Maba.DAL.BaseDAL;
using Maba.VCT.Common;
using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.Core.Events;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    class Hydra2DeviceBL : CommonBL.BaseBLDevice
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

        #endregion

        #region ctor

        public Hydra2DeviceBL(Hydra2BLCore parent) : base(parent)
        {
            connector = new MSSqlServer(parent.DeviceSettings.GeneralDBName);
            connector.Open();
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
            this.StateMachine_Stop.IsActive = false;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_InitSystem,
                this.StateMachine_DateSync,
                this.StateMachine_Rate,
                this.StateMachine_InitChannles,
                this.StateMachine_Logs,
                this.StateMachine_Stop,
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
            var req = new InitSystemRequest();

            switch (singleState.CurrentStep)
            {
                case 0:
                    req.Packet = Common.HydraProtocolHelper.Build_ResetPacket();
                    VCT_Device.Reset(req,
                         res =>
                         {
                             if (res.Result)
                             {
                                 StateMachine_InitSystem.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req.Packet = Common.HydraProtocolHelper.Build_SetFormatPacket();
                    VCT_Device.Format(req,
                         res =>
                         {
                             if (res.Result)
                             {
                                 StateMachine_InitSystem.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req.Packet = Common.HydraProtocolHelper.Build_PrintTypePacket();
                    VCT_Device.PrintType(req, res =>
                    {
                        if (res.Result)
                        {
                            StateMachine_InitSystem.NextStep();
                        }
                        else
                        {
                            throw new Exception();
                        }
                    });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3:
                    req.Packet = Common.HydraProtocolHelper.Build_PrintPacket();
                    VCT_Device.Print(req, res =>
                    {
                        if (res.Result)
                        {
                            StateMachine_InitSystem.NextStep();
                        }
                        else
                        {
                            throw new Exception();
                        }
                    });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Date & Time Sync

        private CommonBL.SingleState.StepWorkResponses StateWork__Date_Sync(CommonBL.SingleState singleState)
        {
            var request = new GetSetDateRequest();
            switch (singleState.CurrentStep)
            {
                case 0:
                    request.Packet = HydraProtocolHelper.Build_SetDatePacket();
                    this.VCT_Device.SetDate(request,
                        res =>
                        {
                            if (res.Result)
                            {
                                StateMachine_DateSync.NextStep();
                            }
                            else
                            {
                                throw new Exception();
                            }
                        });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    request = new GetSetDateRequest();
                    request.Packet = HydraProtocolHelper.Build_SetTimePacket();
                    this.VCT_Device.SetTime(request,
                        res =>
                        {
                            if (res.Result)
                            {
                                StateMachine_DateSync.NextStep();
                            }
                            else
                            {
                                throw new Exception();
                            }
                        });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    request = new GetSetDateRequest();
                    request.Packet = HydraProtocolHelper.Build_GetFullDate();
                    this.VCT_Device.GetFullDate(request,
                        res =>
                        {
                            if (res.Result && DateTime.Now - HydraProtocolHelper.BuildDateFromData(res.ResponsePacket.Command) < TimeSpan.FromMinutes(2))
                            {
                                StateMachine_DateSync.NextStep();
                            }
                            else
                            {
                                throw new Exception();
                            }
                        });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Rate

        private CommonBL.SingleState.StepWorkResponses StateWork__Rate(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var req = new RateRequest();
                    req.Packet = HydraProtocolHelper.Build_SetRatePacket(RateRequest.MeasurementRates.Fast);
                    VCT_Device.Rate(req,
                         res =>
                         {
                             if (res.Result)
                             {
                                 StateMachine_Rate.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    var req1 = new RateRequest(0, 0, 10);
                    req1.Packet = HydraProtocolHelper.Build_SetIntervalPacket(req1);
                    VCT_Device.SetInterval(req1,
                         res =>
                         {
                             if (res.Result)
                             {
                                 StateMachine_Rate.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Init Channels 

        private CommonBL.SingleState.StepWorkResponses StateWork__Init_Channels(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var numberOfChannels = 2;
                    for (var i = 0; i < numberOfChannels; i++)
                    {
                        var req = new InitChannelsRequest(i + 1, InitChannelsRequest.MeasureTypes.TEMP, InitChannelsRequest.ThermocoupleTypes.K);
                        req.Packet = HydraProtocolHelper.Build_InitChannelsPacket(req);
                        VCT_Device.InitChannels(req,
                             res =>
                             {
                                 if (res.Result)
                                 {
                                     StateMachine_Rate.NextStep();
                                 }
                                 else
                                 {
                                     throw new Exception();
                                 }
                             });
                    }
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region Logs 

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.ClearLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ClearLogsPacket();
                    VCT_Device.GetLogs(req, LogResponseCallBack);

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
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
                    case LogsRequest.LogCommands.ClearLogs:
                        req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.StartScan);
                        req.Packet = Common.HydraProtocolHelper.Build_ScanLogsPacket(req);
                        VCT_Device.GetLogs(req, LogResponseCallBack);
                        break;
                    case LogsRequest.LogCommands.StartScan:
                        req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                        req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                        VCT_Device.GetLogs(req, LogResponseCallBack);
                        break;
                    case LogsRequest.LogCommands.LogCount:
                        if (response.LogCount == 0)
                        {
                            req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                            req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                            VCT_Device.GetLogs(req, LogResponseCallBack);
                        }
                        else
                        {
                            for (var i = 0; i < response.LogCount; i++)
                            {
                                req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.GetLogs);
                                req.Packet = Common.HydraProtocolHelper.Build_GetChannelLogPacket(i + 1);
                                VCT_Device.GetLogs(req, LogResponseCallBack);
                            }
                            req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                            req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                            VCT_Device.GetLogs(req, LogResponseCallBack);
                        }
                        break;
                    case LogsRequest.LogCommands.GetLogs:
                        responses.Add(response);
                        break;
                    default:
                        break;
                }
            }
            else
            {
                throw new Exception();
            }
        }

        #endregion

        #endregion
    }
}
