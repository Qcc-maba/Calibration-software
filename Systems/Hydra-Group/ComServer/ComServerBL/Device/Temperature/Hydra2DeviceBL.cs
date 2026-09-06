using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;

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
        private List<LogsResponse> responses = new List<LogsResponse>();
        HydraCalculations HC;
        private HardwareBL_Settings settings;
        private int _initChannelsPending = 0;
        private int _pendingLogEntries = 0;
        private readonly object _logLock = new object();
        #endregion

        #region ctor

        public Hydra2DeviceBL(Hydra2BLCore parent) : base(parent)
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
                    Action_DoWork = StateWork__Init_Channels,
                    DefaultTimeOut = TimeSpan.FromSeconds(60)
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
                    req.Packet = Common.HydraProtocolHelper.Build_ResetPacket(true);
                    HW_Device.Reset(req,
                         res =>
                         {
                             if (res.Result)
                             {
                                 //StateMachine_InitSystem.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    req.Packet = Common.HydraProtocolHelper.Build_SetFormatPacket();
                    HW_Device.Format(req,
                         res =>
                         {
                             if (res.Result)
                             {
                                 //StateMachine_InitSystem.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    req.Packet = Common.HydraProtocolHelper.Build_PrintTypePacket();
                    HW_Device.PrintType(req, res =>
                    {
                        if (res.Result)
                        {
                            //StateMachine_InitSystem.NextStep();
                        }
                        else
                        {
                            throw new Exception();
                        }
                    });
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 3:
                    req.Packet = Common.HydraProtocolHelper.Build_PrintPacket();
                    HW_Device.Print(req, res =>
                    {
                        if (res.Result)
                        {
                            //StateMachine_InitSystem.NextStep();
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
                    this.HW_Device.SetDate(request,
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
                    this.HW_Device.SetTime(request,
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
                    this.HW_Device.GetFullDate(request,
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
                    req.Packet = HydraProtocolHelper.Build_SetRatePacket(settings.Hydra2type.MeasurementRate);
                    HW_Device.Rate(req,
                         res =>
                         {
                             if (res.Result)
                             {
                                 //StateMachine_Rate.NextStep();
                             }
                             else
                             {
                                 throw new Exception();
                             }
                         });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 1:
                    var req1 = new RateRequest(settings.Hydra2type.Interval);
                    req1.Packet = HydraProtocolHelper.Build_SetIntervalPacket(req1);
                    HW_Device.SetInterval(req1,
                         res =>
                         {
                             if (res.Result)
                             {
                                 //StateMachine_Rate.NextStep();
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
                    _initChannelsPending = settings.Hydra2type.Channels.Count;
                    Libs.Trace.Tracer.Info("[HYDRA InitChannels] Queuing FUNC for {0} channels, waiting for all callbacks...", _initChannelsPending);
                    for (var i = 0; i < settings.Hydra2type.Channels.Count; i++)
                    {
                        var channelNum = settings.Hydra2type.Channels[i];
                        var req = new InitChannelsRequest(i + 1);
                        req.Packet = HydraProtocolHelper.Build_InitialChannelsPacket(channelNum, settings.Hydra2type);
                        HW_Device.InitChannels(req,
                             res =>
                             {
                                 var remaining = System.Threading.Interlocked.Decrement(ref _initChannelsPending);
                                 Libs.Trace.Tracer.Info("[HYDRA InitChannels] FUNC callback: Result={0}, remaining={1}", res.Result, remaining);
                                 if (remaining <= 0)
                                 {
                                     Libs.Trace.Tracer.Info("[HYDRA InitChannels] All {0} channels configured, advancing state", settings.Hydra2type.Channels.Count);
                                     StateMachine_InitChannles.NextStep();
                                 }
                             });
                    }
                    // Wait4Work: state stays in Wait mode until all callbacks fire and the last one calls NextStep()
                    return CommonBL.SingleState.StepWorkResponses.Wait4Work;
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
                    HW_Device.GetLogs(req, LogResponseCallBack);

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void LogResponseCallBack(LogsResponse response)
        {
            Libs.Trace.Tracer.Info("[HYDRA LogResponseCallBack] Result={0}, LogCommand={1}, LogCount={2}",
                response.Result, response.LogCommand, response.LogCount);

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
                            // Delay polling to ~30 seconds to match device scan interval (INTVL 0,0,30)
                            System.Threading.Tasks.Task.Delay(28000).ContinueWith(_ =>
                            {
                                var pollReq = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                                pollReq.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                                HW_Device.GetLogs(pollReq, LogResponseCallBack);
                            });
                        }
                        else
                        {
                            // Track how many log entries we're fetching so we broadcast only once (on the last one)
                            lock (_logLock) { _pendingLogEntries = response.LogCount; }
                            for (var i = 0; i < response.LogCount; i++)
                            {
                                req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.GetLogs);
                                req.Packet = Common.HydraProtocolHelper.Build_GetChannelLogPacket(i + 1);
                                HW_Device.GetLogs(req, HandleLogData);
                            }
                            // LOG_CLR is now sent from HandleLogData after the last entry is processed
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
                Libs.Trace.Tracer.Info("[HYDRA LogResponseCallBack] Result=False for LogCommand={0}, retrying LOG_COUNT...", response.LogCommand);
                // Instead of crashing, retry LOG_COUNT? polling
                var retryReq = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                retryReq.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                HW_Device.GetLogs(retryReq, LogResponseCallBack);
            }
        }

        private void LogClearAfterReadCallback(LogsResponse response)
        {
            Libs.Trace.Tracer.Info("[HYDRA LogClearAfterRead] Result={0}, resuming LOG_COUNT polling", response.Result);
            // After clearing, resume LOG_COUNT? polling for new scan data
            var req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
            req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
            HW_Device.GetLogs(req, LogResponseCallBack);
        }

        private void HandleLogData(LogsResponse response)
        {
            Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Received LogsResponse: Measurements.Count={0}, Configured Channels.Count={1}",
                response.Measurements.Count, settings.Hydra2type.Channels.Count);

            for (int m = 0; m < response.Measurements.Count; m++)
            {
                Libs.Trace.Tracer.Info("[HYDRA HandleLogData]   Raw measurement[{0}] = {1}", m, response.Measurements[m]);
            }

            // TODO Change to Device ID
            HC.ProcessResults(response, settings.Hydra2type);

            // Only broadcast on the LAST log entry to avoid flooding WS clients
            int remaining;
            lock (_logLock) { remaining = --_pendingLogEntries; }

            if (remaining <= 0)
            {
                // Broadcast real channel measurements in a single WebSocket message
                var channels = new System.Collections.Generic.List<int>();
                var values = new System.Collections.Generic.List<double>();

                var masterID = settings.Hydra2type.Masters.FirstOrDefault();
                for (int i = 0; i < response.Measurements.Count && i < settings.Hydra2type.Channels.Count; i++)
                {
                    // Skip disconnected channels (Hydra returns 9.00E+9 = 9000000000 for open/no-sensor channels)
                    if (response.Measurements[i] >= 9000000000)
                        continue;

                    // Apply deviation correction before broadcasting
                    double rawValue = response.Measurements[i];
                    var corrected = HC.CalcDeviationForTemperature(rawValue, masterID);
                    var logLine = string.Format("[HYDRA Correction] CH{0} | Raw={1:F4} | Corrected={2:F4} | Status={3} | MasterID={4}",
                        settings.Hydra2type.Channels[i], rawValue, corrected.Item1, corrected.Item2, masterID);
                    Libs.Trace.Tracer.Info(logLine);
                    System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + " " + logLine + Environment.NewLine);
                    channels.Add(settings.Hydra2type.Channels[i]);
                    values.Add(corrected.Item1);
                }

                Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Broadcasting {0} channels (last entry): [{1}] values: [{2}]",
                    channels.Count,
                    string.Join(",", channels),
                    string.Join(",", values.Select(v => v.ToString(System.Globalization.CultureInfo.InvariantCulture))));

                HW_Device.BroadcastAllMeasurements(channels, values);

                // Clear logs AFTER all entries are read and broadcast, then resume polling
                var clearReq = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.ClearLogs);
                clearReq.Packet = Common.HydraProtocolHelper.Build_ClearLogsPacket();
                HW_Device.GetLogs(clearReq, LogClearAfterReadCallback);
            }
            else
            {
                Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Skipping broadcast, {0} log entries still pending", remaining);
            }
        }
    }

    #endregion

    #endregion
}
