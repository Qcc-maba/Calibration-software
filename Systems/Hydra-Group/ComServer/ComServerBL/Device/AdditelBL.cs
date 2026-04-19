using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;
using Maba.VCT.CommServer.BL.HydaDevices.BLCore;

namespace Maba.VCT.CommServer.BL.HydaDevices.Device
{
    public class AdditelBL : CommonBL.BaseBLDevice
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

        public AdditelBL(AdditelBLCore parent) : base(parent)
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
                    #region Start Step
                    return false;
                #endregion
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
                    req.Packet = Common.HydraProtocolHelper.buildClearBuffer();
                    HW_Device.Reset(req);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    foreach (var item in settings.Additel.Channels)
                    {
                        var SenType = settings.Additel.Sensor.SensType == SensorType.SensorTypes.TCouple ? 0 : 2;
                        req.Packet = Common.HydraProtocolHelper.Build_ChannelConfiguration(item, settings.Additel.Sensor.numbertOfWires, SenType);
                        HW_Device.Reset(req);
                    }

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;

            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void ResponseCallback(LogsResponse response)
        {
            //var res = response.Message.Split(',');
            //var Ohm = res[3];
            if (response.HasResponse)
            {
                HC.ProcessResults(response, settings.Additel);
            }

            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = Common.HydraProtocolHelper.Build_ScanData();
            HW_Device.GetLogs(req, ResponseCallback);

        }

        #endregion

        #region Logs 

        private CommonBL.SingleState.StepWorkResponses StateWork__Logs(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
                    req.Packet = Common.HydraProtocolHelper.Build_ScanData();
                    HW_Device.GetLogs(req, ResponseCallback);

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
