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
using WebSocketSharp;

namespace Maba.VCT.CommServer.BL.HydaDevices.Device
{
    public class TTIDeviceBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        //public const int STATE_MACHINE__Date_Sync = 2;
        //public const int STATE_MACHINE__Rate = 3;
        //public const int STATE_MACHINE__InitChannels = 4;
        //public const int STATE_MACHINE__Logs = 5;
        //public const int STATE_MACHINE__Stop = 6;



        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        //public CommonBL.SingleState StateMachine_DateSync { get; private set; }
        //public CommonBL.SingleState StateMachine_Rate { get; private set; }
        //public CommonBL.SingleState StateMachine_InitChannles { get; private set; }
        //public CommonBL.SingleState StateMachine_Logs { get; private set; }
        //public CommonBL.SingleState StateMachine_Stop { get; private set; }

        #endregion

        #region properties
        private HydraCalculations HC;
        private HardwareBL_Settings settings;

        #endregion

        #region ctor

        public TTIDeviceBL(TTIBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;
            HC = new HydraCalculations(parent.VCT_Server.connector);
        }

        #endregion

        #region overridden from CommonBL.BaseBLDevice

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            HC.Init(settings.Hydra3type.Masters);

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

            //if (this.StateMachine_Logs == null)
            //{
            //    this.StateMachine_Logs = new CommonBL.SingleState(STATE_MACHINE__Logs, "Logs")
            //    {
            //        Action_DoWork = StateWork__Logs
            //    };
            //}


            this.StateMachine_InitSystem.IsActive = true;
            //this.StateMachine_DateSync.IsActive = true;
            //this.StateMachine_Rate.IsActive = true;
            //this.StateMachine_InitChannles.IsActive = true;
            //this.StateMachine_Logs.IsActive = true;
            //this.StateMachine_Stop.IsActive = false;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_InitSystem,
                //this.StateMachine_DateSync,
                //this.StateMachine_Rate,
                //this.StateMachine_InitChannles,
                //this.StateMachine_Logs,
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
                    this.StateMachine_InitSystem.IsActive = true;
                    //moving on from Start step is OK for online device only.
                    //if (this.Metadata != null && this.Metadata.DeviceType != null && this.Metadata.DeviceType.OnlineDevice)
                    //{
                    //    //prepare to routine
                    //    this.StateMachine_IrrigatingValves.IsActive = false;
                    //    this.StateMachine_ReadIO.IsActive = true;

                    //    this.StateMachine_Read_Memory.IsActive = false;
                    //    this.StateMachine_WriteMemory.IsActive = false;
                    return true;
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
        }
        #endregion

        #region private methods :: StateMachines

        #region Init system
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            LogsRequest req;

            switch (singleState.CurrentStep)
            {
                case 0:
                    req = new LogsRequest(LogsRequest.LogCommands.GetLogs)
                    {
                        Packet = HydraProtocolHelper.GetTTIData()
                    };
                    HW_Device.GetLogs(req, LogResponseCallBack);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion


        #region Logs 


        private void LogResponseCallBack(LogsResponse response)
        {
            try
            {
                LogsRequest req;
                switch (response.LogCommand)
                {
                    case LogsRequest.LogCommands.GetLogs:
                        req = new LogsRequest(LogsRequest.LogCommands.GetLogs)
                        {
                            Packet = HydraProtocolHelper.GetTTIData()
                        };
                        //HW_Device.GetLogs(req, LogResponseCallBack);
                        if (response.HasResponse)
                        {
                            //HandelLogs(response);
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                // Log the exception with details
                Console.WriteLine($"An error occurred in LogResponseCallBack: {ex.Message}", ex);
                throw; // Re-throw the exception if necessary
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

            HC.ProcessResults(response, settings.TTI22);
        }
        #endregion
    }
}
