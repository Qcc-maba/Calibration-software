using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.CommonBL
{
    /// <summary>
    /// One step of a device's state machine. Action_DoWork is invoked repeatedly with an advancing
    /// CurrentStep and returns <see cref="StepWorkResponses"/>: Skip2NextStep to move to the next
    /// step, StateFinished when the state is done.
    /// </summary>
    public class SingleState
    {
        #region enums

        public enum StepWorkResponses
        {
            Wait4Work,
            Skip2NextStep,
            StateFinished
        }

        public enum StateModes
        {
            Step,
            Wait,
            Expired,
            CyclePending
            /// <summary>
            /// The only way out - is re-connection of device (then we call to ResetState())
            /// </summary>
            //DeadEnd
        };

        #endregion

        #region properties

        public bool IsActive { get; set; }

        public StateModes StateMode { get; set; } = StateModes.Step;

        public DateTime? LastStateChange { get; set; } = null;
        public DateTime StateExpireTime { get; set; }

        public DateTime? NextManualExecutionTime { get; set; }
        public TimeSpan? ManualExecutionInterval { get; set; }

        public int CurrentStep { get; set; } = 0;

        public string Name { get; private set; }
        public int State { get; private set; }

        public TimeSpan DefaultTimeOut { get; set; } = TimeSpan.FromSeconds(5);

        public Func<SingleState, StepWorkResponses> Action_DoWork { get; set; }

        /// <summary>
        /// Guards step changes: a step that waits for a reply is moved on from the thread that
        /// delivers the reply, while the device timer drives <see cref="DoWork"/>.
        /// </summary>
        private readonly object _stepLock = new object();

        #endregion

        #region ctor

        public SingleState(int state, string name = "")
        {
            State = state;
            Name = name;
            this.ManualExecutionInterval = TimeSpan.FromSeconds(2);
        }

        #endregion

        #region public methods 

        public void DoWork(DateTime now)
        {
            if (!IsActive && this.StateMode != StateModes.CyclePending)
            {
                this.StateMode = StateModes.CyclePending;
            }

            switch (StateMode)
            {
                case StateModes.Step:
                    if (!IsActive || Action_DoWork != null)
                    {
                        StateExpireTime = now.Add(DefaultTimeOut);
                        var stepBefore = CurrentStep;
                        var response = Action_DoWork(this);
                        switch (response)
                        {
                            case StepWorkResponses.Wait4Work:
                                // MBA-967: the reply can arrive before Action_DoWork has even returned,
                                // and its callback has then already moved the step on. Waiting regardless
                                // parked the next step until the timeout, which then moved it on a second
                                // time and skipped it.
                                lock (_stepLock)
                                {
                                    if (CurrentStep == stepBefore)
                                    {
                                        this.StateMode = StateModes.Wait;
                                    }
                                }
                                break;
                            case StepWorkResponses.Skip2NextStep:
                                NextStep();
                                break;
                            default:
                            case StepWorkResponses.StateFinished:
                                this.StateMode = StateModes.CyclePending;
                                break;
                        }
                        //Libs.Trace.Tracer.Info("State {0} :: [{1}] Step:{2}", this.Name, StateMode, this.CurrentStep);
                    }

                    else
                    {
                        this.StateMode = StateModes.CyclePending;
                    }
                    break;
                case StateModes.Wait:
                    if (now > StateExpireTime)
                    {
                        this.StateMode = StateModes.Expired;
                    }
                    break;
                case StateModes.Expired:
                    NextStep();
                    this.StateMode = StateModes.Step;
                    break;
                case StateModes.CyclePending:
                    if (NextManualExecutionTime.HasValue)
                    {
                        if (now >= NextManualExecutionTime.Value)
                        {
                            //settings the NextManualExecutionTime cause to single execution.
                            ResetState();

                            //if ManualExecutionInterval is set - so another execution is set again.
                            if (ManualExecutionInterval.HasValue)
                            {
                                NextManualExecutionTime = now.Add(ManualExecutionInterval.Value);
                            }
                        }
                    }
                    else
                    {
                        if (ManualExecutionInterval.HasValue)
                        {
                            NextManualExecutionTime = now.Add(ManualExecutionInterval.Value);
                        }
                    }
                    break;
            }
        }

        public void ResetState()
        {
            this.CurrentStep = 0;
            LastStateChange = null;
            StateExpireTime = DateTime.UtcNow.Add(DefaultTimeOut);
            StateMode = StateModes.Step;

            NextManualExecutionTime = null;
        }

        public void NextStep()
        {
            lock (_stepLock)
            {
                CurrentStep++;
                LastStateChange = DateTime.UtcNow;
                StateExpireTime = DateTime.UtcNow.Add(DefaultTimeOut);
                StateMode = StateModes.Step;
            }
        }

        /// <summary>
        /// Moves on from <paramref name="step"/> only if the state is still on it - for a reply that
        /// may come back after its step timed out and the state has already moved on without it.
        /// </summary>
        /// <returns>True when the state moved on.</returns>
        public bool NextStepFrom(int step)
        {
            lock (_stepLock)
            {
                if (CurrentStep != step) return false;
                NextStep();
                return true;
            }
        }
        public void SetTimeout(TimeSpan? StepTimeout = null)
        {
            StateExpireTime = DateTime.UtcNow.Add(StepTimeout ?? DefaultTimeOut);
        }

        #endregion
    }

}
