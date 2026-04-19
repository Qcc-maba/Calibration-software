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
    public class Agilent34401aBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Logs = 2;
        public const int STATE_MACHINE__Stop = 3;



        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Logs { get; private set; }
        public CommonBL.SingleState StateMachine_Stop { get; private set; }
        #endregion

        #region properties

        HydraCalculations HC;
        private HardwareBL_Settings settings;
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
            HC.Init(settings.Hydra2type.Masters).GetAwaiter().GetResult();

            if (this.StateMachine_InitSystem == null)
            {
                this.StateMachine_InitSystem = new CommonBL.SingleState(STATE_MACHINE__InitSystem, "Init System")
                {
                    Action_DoWork = StateWork__InitSystem
                };
            }

            //if (this.StateMachine_DateSync == null)
            //{
            //    this.StateMachine_DateSync = new CommonBL.SingleState(STATE_MACHINE__Date_Sync, "Date Sync")
            //    {
            //        Action_DoWork = StateWork__Date_Sync
            //    };
            //}

            //if (this.StateMachine_Rate == null)
            //{
            //    this.StateMachine_Rate = new CommonBL.SingleState(STATE_MACHINE__Rate, "Rate")
            //    {
            //        Action_DoWork = StateWork__Rate
            //    };
            //}

            //if (this.StateMachine_InitChannles == null)
            //{
            //    this.StateMachine_InitChannles = new CommonBL.SingleState(STATE_MACHINE__InitChannels, "InitChannels")
            //    {
            //        Action_DoWork = StateWork__Init_Channels
            //    };
            //}

            if (this.StateMachine_Logs == null)
            {
                this.StateMachine_Logs = new CommonBL.SingleState(STATE_MACHINE__Logs, "Logs")
                {
                    Action_DoWork = StateWork__Logs
                };
            }


            this.StateMachine_InitSystem.IsActive = true;
            //this.StateMachine_DateSync.IsActive = true;
            //this.StateMachine_Rate.IsActive = true;
            //this.StateMachine_InitChannles.IsActive = true;
            this.StateMachine_Logs.IsActive = true;
            //this.StateMachine_Stop.IsActive = false;

            var states = new CommonBL.SingleState[]
            {
            this.StateMachine_InitSystem,
            //this.StateMachine_DateSync,
            //this.StateMachine_Rate,
            //this.StateMachine_InitChannles,
            this.StateMachine_Logs,
                //this.StateMachine_Stop,
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
            // Receving Web Socket data
            base.OnEvent(e);

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
                    req.Packet = Common.HydraProtocolHelper.Build_ResetPacket(false);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req.Packet = Common.HydraProtocolHelper.Build_RemotePacket();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req.Packet = Common.HydraProtocolHelper.buildClearBuffer();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3:
                    req.Packet = Common.HydraProtocolHelper.Build_Configuration(settings.Agilent.Sensor);
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 4:
                    req.Packet = Common.HydraProtocolHelper.Build_AutoRange(settings.Agilent.Sensor);
                    HW_Device.Reset(req);
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
                    var req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.GetLogs);
                    req.Packet = Common.HydraProtocolHelper.BuildRead();
                    HW_Device.GetLogs(req, LogResponseCallBack);

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
                        HW_Device.GetLogs(req, LogResponseCallBack);
                        break;
                    case LogsRequest.LogCommands.StartScan:
                        req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                        req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                        HW_Device.GetLogs(req, LogResponseCallBack);
                        break;
                    case LogsRequest.LogCommands.LogCount:
                        if (response.LogCount == 0)
                        {
                            req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                            req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                            HW_Device.GetLogs(req, LogResponseCallBack);
                        }
                        else
                        {
                            for (var i = 0; i < response.LogCount; i++)
                            {
                                req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.GetLogs);
                                req.Packet = Common.HydraProtocolHelper.Build_GetChannelLogPacket(i + 1);
                                HW_Device.GetLogs(req, HandleLogData);
                            }
                            req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                            req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                            HW_Device.GetLogs(req, LogResponseCallBack);
                        }
                        break;
                    case LogsRequest.LogCommands.GetLogs:
                        req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                        req.Packet = HydraProtocolHelper.BuildRead();
                        HW_Device.GetLogs(req, LogResponseCallBack);
                        HandleLogData(response);
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

        private void HandleLogData(LogsResponse response)
        {

            // TODO Change to Device ID
            //HC.ProcessResults(response, settings.Agilent);
            foreach (var item in settings.Agilent.Masters)
            {
                var res = HC.CalcConversionUnits(response.Measurements.FirstOrDefault(), HydraCalculations.ConversionUnits.Ohm, HydraCalculations.ConversionUnits.Celsius, item);
                HC.ProcessResults(response, settings.Agilent);
                Console.WriteLine(" The results is: " + response.Measurements.FirstOrDefault());
            }


        }
    }

    #endregion

    #endregion
}
