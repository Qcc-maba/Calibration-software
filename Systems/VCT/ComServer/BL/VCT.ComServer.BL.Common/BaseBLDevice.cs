using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.VCT.Common;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;


namespace Maba.VCT.CommServer.CommonBL
{
    /// <summary>
    /// Base class for a single device's business logic. Subclasses describe the instrument as an
    /// ordered set of <see cref="SingleState"/> steps returned from OnCreateStates (e.g.
    /// reset → configure → acquire); the base runs them on the server timer and exposes the
    /// device host as HW_Device. See docs/architecture.md.
    /// </summary>
    public abstract class BaseBLDevice : Core.Device.IDeviceBL
    {
        #region enums
        public enum DeviceSteps
        {
            Start,
            Routine,
            Close
        }

        #endregion

        #region members

        private int States_CurrentIndex = 0;
        private int States_Count = 0;

        private SingleState[] States = null;
        #endregion

        #region properties

        public IBLCore Parent { get; private set; }
        public Core.Device.HardwareDeviceHost HW_Device { get; private set; }
        public Core.Device.WebSocketDeviceHost WS_Device { get; private set; }
        public DeviceSteps CurrentStep { get; private set; } = DeviceSteps.Start;
        #endregion

        #region ctor

        public BaseBLDevice(IBLCore parent)
        {
            Parent = parent;
        }

        #endregion

        #region private methods

        private void Step__Routine_Work()
        {
            DateTime now = DateTime.UtcNow;

            for (int i = 0; i < States_Count; i++)
            {
                States[i].DoWork(now);
            }
        }

        private void Step__Start_Work()
        {
            DateTime now = DateTime.UtcNow;
            var state = States[States_CurrentIndex];

            //VCT.Libs.Trace.Tracer.Info($"Device #{this.VCT_Device.SN} - [Step__Start_Work] - [{state.State}:{state.Name}]");

            state.DoWork(now);

            if (state.StateMode == SingleState.StateModes.CyclePending)
            {
                //when arrived last state - go to next Step
                States_CurrentIndex++;

                if (States_CurrentIndex >= States_Count)
                {
                    if (OnStepStart(DeviceSteps.Routine))
                    {
                        VCT.Libs.Trace.Tracer.Info($"Device #{this.HW_Device.SN} - [Step__Routine_Work]");

                        //go to next step
                        CurrentStep = DeviceSteps.Routine;
                    }
                    else
                    {
                        CurrentStep = DeviceSteps.Close;

                        //disconnect VCT device as we done with this device.
                        //To see you next connection...
                        //this.VCT_Device.Disconnect();
                    }
                }
            }
        }

        #endregion

        #region IDeviceBL members

        public bool OnConnection(bool state)
        {
            if (state)
            {
                //VCT.Libs.Trace.Tracer.Info($"Device #{this.VCT_Device.SN} - [Start {this.GetType().Name} BL]");

                //reset step
                CurrentStep = DeviceSteps.Start;
                States_CurrentIndex = 0;

                this.States = OnCreateStates();

                //create states array if none..
                if (this.States == null || this.States.Length == 0)
                {
                    this.States = new SingleState[]
                    {
                            new SingleState(0)
                            {
                                 DefaultTimeOut = TimeSpan.FromSeconds(1),
                            }
                    };
                }

                this.States_Count = States.Length;

                //reset states array
                for (int i = 0; i < States_Count; i++)
                {
                    States[i].ResetState();
                }
            }

            return true;
        }

        public virtual void OnEvent(DeviceEventArgs e)
        {
        }

        public void OnTimer()
        {
            if (this.HW_Device != null && HW_Device.IsConnected)
            {
                switch (CurrentStep)
                {
                    case DeviceSteps.Start:
                        Step__Start_Work();
                        break;
                    case DeviceSteps.Routine:
                        Step__Routine_Work();
                        break;
                    default:
                    case DeviceSteps.Close:
                        //do nothing!!
                        break;
                }
            }
        }

        public void Start(IDeviceHost device)
        {
            if (device is HardwareDeviceHost host)
            {
                OnConnection(true);
                HW_Device = host;
                HW_Device.BL = this;
            }
            else
            {
                WS_Device = (WebSocketDeviceHost)device;
                WS_Device.BL = this;
            }
        }

        public void Disconnect()
        {

        }

        #endregion

        #region protected/virtual methods

        protected abstract SingleState[] OnCreateStates();

        protected abstract bool OnStepStart(DeviceSteps step);

        #endregion
    }
}
