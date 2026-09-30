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

        /// <summary>
        /// What the Hydra reports for an open input: 9.00E+9. It is the instrument's way of saying
        /// "no sensor on this channel", not a temperature, and it arrives looking like any other
        /// reading — which is why a lost thermocouple used to cost points off a calibration in
        /// complete silence (MBA-962, disconnect type 3).
        /// </summary>
        public const double DISCONNECTED_CHANNEL_READING = 9000000000;

        /// <summary>This BL's key in <see cref="HardwareBL_Settings"/> - it must match the name used by
        /// that class's family list, since that is how the operator's configuration is routed here.</summary>
        public const string SETTINGS_FAMILY = "Hydra2";

        public override string SettingsFamily => SETTINGS_FAMILY;



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

        /// <summary>The log entries of the batch being read, broadcast together once the last arrives.</summary>
        private readonly List<LogsResponse> _pendingEntries = new List<LogsResponse>();

        /// <summary>
        /// MBA-967: which polling loop is the live one. Every init starts a new loop
        /// (LOG_CLR -> SCAN -> LOG_COUNT? ...), and a re-init drops only the request in flight - a
        /// loop that is sleeping through its 28 s wait wakes up afterwards and carries on beside the
        /// new one. Nofar's logs show the LOG_COUNT? rate climbing from 2 to 7 per 30 s scan as
        /// app-driven re-inits piled up, and at three or more loops one loop's LOG_CLR landed between
        /// another's LOG_COUNT? and LOGGED?: the logger answered "!>" and the scan was gone - 1,291
        /// scans across 14-30 Sep, cured only by restarting the software. Each loop now carries the
        /// generation it was started with, and stops at its next step once a newer one exists.
        /// </summary>
        private int _pollGeneration;

        /// <summary>
        /// MBA-967: the logger scan time of the newest entry sent, so a scan read a second time is not
        /// sent again. Every entry of a batch is broadcast, and the batch is cleared from the logger
        /// only afterwards; when that LOG_CLR fails the entries stay in the buffer, and the next poll
        /// reads them all again together with the new one. Without this, each failed clear re-sent a
        /// growing run of old points, with times running backwards in the app.
        /// <para>
        /// Reset by every init: <c>TIME</c> sets the logger's clock back to the start of the minute, so
        /// the first scans after a re-init can carry earlier times than the last one sent before it.
        /// </para>
        /// </summary>
        private DateTime? _lastBroadcastScanTime;

        /// <summary>
        /// MBA-967: how far the logger's clock is behind the PC's (PC minus logger). Null until it has
        /// been read, and then readings go out with the send time, as they always did.
        /// <para>
        /// It is never zero, because the logger cannot be set to the second: <c>TIME</c> takes hours
        /// and minutes only and sets the seconds to 00 (2620A/2625A manual, Table 4-8). So every
        /// init leaves the logger behind by however far into the minute it ran - 58 s after the
        /// 19:42:57 re-init on 2026-09-29. <c>TIME_DATE?</c> does return seconds, so the difference
        /// is measured instead of set.
        /// </para>
        /// </summary>
        private TimeSpan? _loggerClockOffset;

        /// <summary>When the logger's clock was last read (UTC), successfully or not.</summary>
        private DateTime? _loggerClockReadUtc;

        /// <summary>How often the offset is re-read during a run, so a drifting logger clock cannot accumulate.</summary>
        internal static readonly TimeSpan LoggerClockRefreshInterval = TimeSpan.FromMinutes(10);

        /// <summary>
        /// A re-read offset replaces the current one only when it differs by more than this. The logger
        /// reports whole seconds, so two readings of the same clock differ by up to a second on their
        /// own; adopting each one would shift every later reading by a second and put back the very
        /// 29/31 s unevenness the offset exists to remove. Real drift passes this within a refresh or two.
        /// </summary>
        internal static readonly TimeSpan LoggerClockDriftTolerance = TimeSpan.FromSeconds(1.5);

        /// <summary>
        /// Channels currently reporting an open input, so the alert fires on the transition rather
        /// than on every scan. A logger scanning at the usual rate would otherwise emit an alert per
        /// channel every couple of seconds for as long as the sensor stays out, and the operator
        /// would learn to ignore the whole alert area.
        /// </summary>
        private readonly HashSet<int> _disconnectedChannels = new HashSet<int>();
        #endregion

        #region ctor

        public Hydra2DeviceBL(Hydra2BLCore parent) : base(parent)
        {
            HC = new HydraCalculations(new ComServerBL.Hydra2.DAL.Calibration.CalibrationRepository());
            settings = parent.DeviceSettings;
        }

        #endregion

        #region overridden from CommonBL.BaseBLDevice

        /// <summary>
        /// A communication interruption leaves the same log entry being read again: on a station,
        /// <c>1,20.9917353964817</c> was re-broadcast unchanged every 34 seconds while the watchdog
        /// counted it as a healthy device.
        /// <para>
        /// This used to say that a Hydra never returns the same number twice, so an identical reading
        /// had to be a re-read. That is false (MBA-967): the logger reports to 0.1 °C, and a settled
        /// bath gives identical scans for minutes. Judged on values alone, a stable overnight run was
        /// declared stalled three times and reset each time. Every reading therefore carries the
        /// logger's own scan time into the comparison - see <see cref="BroadcastEntry"/>. A re-read
        /// entry is not sent again at all now (its scan time is not newer than the last one sent), so
        /// a logger stuck on one entry goes silent and the data watchdog, not this check, reports it.
        /// </para>
        /// </summary>
        protected override bool DetectsStaleData { get { return true; } }

        protected override CommonBL.SingleState[] OnCreateStates()
        {
            // Also the re-init entry point (HardwareDeviceHost.ReinitializeBL after a power cycle).
            // The channel state has to go with it: the device is about to be set up from scratch, and
            // a channel remembered as disconnected would never announce its recovery.
            _disconnectedChannels.Clear();

            // The init sets the logger's clock again, so the old offset no longer describes it, and a
            // batch interrupted by the reset is never going to finish.
            _loggerClockOffset = null;
            _loggerClockReadUtc = null;
            _lastBroadcastScanTime = null;
            lock (_logLock)
            {
                _pendingLogEntries = 0;
                _pendingEntries.Clear();
            }
            System.Threading.Interlocked.Increment(ref _pollGeneration);

            // Says "a Hydra 2625A is the thing being driven here", so the operator's channel list can
            // be routed to this family even when the logger's MABA id is not in the settings file's
            // Masters list - which is the normal case on any station but the one the file was
            // written for. See HardwareBL_Settings.ApplyWebSocketConfig.
            HardwareBL_Settings.RegisterActiveFamily(SETTINGS_FAMILY);

            // MBA-967: on the operator's first Confirm the channel list arrives before this BL exists,
            // and is held. Applying it here, before the InitChannels state reads settings, is what makes
            // the first init scan the operator's channels instead of the settings file's.
            var held = settings.ApplyPendingWebSocketConfig(SETTINGS_FAMILY, DateTime.UtcNow, out var ambiguous);
            if (held != null)
            {
                Libs.Trace.Tracer.Info("[WS->HW] Applied the configuration received before the logger was identified: {0}", held);
            }
            else if (ambiguous != null)
            {
                // Identification gives the serial number, not the MABA id, so there is no telling which
                // of these is this logger's. The next Confirm reaches it through the live path.
                Libs.Trace.Tracer.Info("[WS->HW] Configurations for loggers {0} were held before any logger was identified; " +
                                       "cannot tell which is this one, so none was applied and all were dropped. " +
                                       "Using the current settings until the next Confirm.", ambiguous);
            }

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

        // Each step returns Skip2NextStep and nothing else advances the state. The callbacks used to
        // call NextStep() as well, so the DATE reply moved the state on a second time and step 2 -
        // the TIME_DATE? read - was skipped on every init: the station logs show DATE, TIME, RATE and
        // never a TIME_DATE? (MBA-967). The other states already had those calls commented out.
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
                            if (!res.Result)
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
                            if (!res.Result)
                            {
                                throw new Exception();
                            }
                        });

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
                case 2:
                    ReadLoggerClock();
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>
        /// MBA-967: asks the logger for its clock (<c>TIME_DATE?</c>) to measure how far it is from the
        /// PC's. A failed read only costs accuracy - readings go out with the send time, as before - so
        /// it never stops the init, unlike the old check here, which threw.
        /// </summary>
        private void ReadLoggerClock()
        {
            _loggerClockReadUtc = DateTime.UtcNow;
            var request = new GetSetDateRequest();
            request.Packet = HydraProtocolHelper.Build_GetFullDate();
            this.HW_Device.GetFullDate(request, OnLoggerClockRead);
        }

        private void OnLoggerClockRead(GetSetDateResponse res)
        {
            var pcNow = DateTime.Now;
            var reply = res != null && res.Result && res.ResponsePacket != null ? res.ResponsePacket.ToString() : null;

            if (!HydraProtocolHelper.TryBuildDateFromData(reply, out var loggerClock))
            {
                Libs.Trace.Tracer.Info("[HYDRA Clock] Could not read the logger clock (reply '{0}'); keeping offset {1}",
                    reply, _loggerClockOffset.HasValue ? _loggerClockOffset.Value.TotalSeconds.ToString("F1", System.Globalization.CultureInfo.InvariantCulture) + "s" : "none - readings use the send time");
                return;
            }

            var measured = MeasureLoggerClockOffset(pcNow, loggerClock);
            var adopted = ChooseLoggerClockOffset(_loggerClockOffset, measured);
            _loggerClockOffset = adopted;

            Libs.Trace.Tracer.Info("[HYDRA Clock] Logger {0:HH:mm:ss}, PC {1:HH:mm:ss.fff}: measured offset {2:F1}s, using {3:F1}s",
                loggerClock, pcNow, measured.TotalSeconds, adopted.TotalSeconds);
        }

        /// <summary>
        /// PC time minus logger time. The logger reports whole seconds and drops the fraction, so its
        /// true time is on average half a second past what it says; the half second is added back so
        /// the offset is centred rather than biased late.
        /// </summary>
        internal static TimeSpan MeasureLoggerClockOffset(DateTime pcNow, DateTime loggerClock)
        {
            return pcNow - loggerClock.AddMilliseconds(500);
        }

        /// <summary>
        /// Keeps the current offset unless the new measurement has moved past
        /// <see cref="LoggerClockDriftTolerance"/>: whole-second readings disagree by up to a second
        /// on their own, and following them would shift every later reading by that second.
        /// </summary>
        internal static TimeSpan ChooseLoggerClockOffset(TimeSpan? current, TimeSpan measured)
        {
            if (!current.HasValue) return measured;
            return (measured - current.Value).Duration() > LoggerClockDriftTolerance ? measured : current.Value;
        }

        /// <summary>
        /// The logger's scan time moved onto the PC's clock, for the reading's <c>Time</c>. Null - send
        /// time - when the entry carried no scan time or the logger's clock has not been read.
        /// <para>
        /// The half second goes back in here too. The offset is measured against the logger's true
        /// time (reported second + 0.5), so the scan time has to be put on the same footing; without it
        /// every reading came out half a second early - on the bench the first scan, taken at
        /// 13:45:18.2 when SCAN was sent, was stamped 13:45:17.
        /// </para>
        /// </summary>
        internal static DateTime? ScanTimeOnPcClock(DateTime loggerScanTime, TimeSpan? loggerClockOffset)
        {
            if (loggerScanTime == default(DateTime) || !loggerClockOffset.HasValue) return null;
            return loggerScanTime.AddMilliseconds(500) + loggerClockOffset.Value;
        }

        internal static bool LoggerClockDue(DateTime? lastReadUtc, DateTime nowUtc)
        {
            return !lastReadUtc.HasValue || nowUtc - lastReadUtc.Value >= LoggerClockRefreshInterval;
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
                    var generation = System.Threading.Volatile.Read(ref _pollGeneration);
                    Libs.Trace.Tracer.Info("[HYDRA Poll] Starting polling loop #{0}", generation);

                    // MBA-967: the channel setup that just finished took ~2 s per channel, and the first
                    // reading is up to ~28 s away yet. Restarting the watchdog only when the re-init was
                    // queued left 16-20 channels past the 60 s. Guarded in the host: a device already
                    // declared silent (power-cycle recovery) or never measured keeps its clock.
                    if (HW_Device.RestartWatchdogClockForReconfiguration(DateTime.UtcNow))
                    {
                        Libs.Trace.Tracer.Info("[HYDRA Poll] Channel setup finished; the data watchdog counts from here");
                    }

                    HW_Device.GetLogs(req, r => LogResponseCallBack(r, generation));

                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>True, and logged, when <paramref name="generation"/> is an outdated polling loop.</summary>
        private bool IsStalePoll(int generation, string step)
        {
            var current = System.Threading.Volatile.Read(ref _pollGeneration);
            if (generation == current) return false;
            Libs.Trace.Tracer.Info("[HYDRA Poll] Stopping polling loop #{0} at {1}; loop #{2} is the live one", generation, step, current);
            return true;
        }

        private void LogResponseCallBack(LogsResponse response)
        {
            LogResponseCallBack(response, System.Threading.Volatile.Read(ref _pollGeneration));
        }

        private void LogResponseCallBack(LogsResponse response, int generation)
        {
            Libs.Trace.Tracer.Info("[HYDRA LogResponseCallBack] Result={0}, LogCommand={1}, LogCount={2}",
                response.Result, response.LogCommand, response.LogCount);

            if (IsStalePoll(generation, response.LogCommand.ToString())) return;

            if (response.Result)
            {
                LogsRequest req;
                switch (response.LogCommand)
                {
                    case LogsRequest.LogCommands.ClearLogs:
                        req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.StartScan);
                        req.Packet = Common.HydraProtocolHelper.Build_ScanLogsPacket(req);
                        HW_Device.GetLogs(req, r => LogResponseCallBack(r, generation));
                        break;
                    case LogsRequest.LogCommands.StartScan:
                        req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                        req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                        HW_Device.GetLogs(req, r => LogResponseCallBack(r, generation));
                        break;
                    case LogsRequest.LogCommands.LogCount:
                        if (response.LogCount == 0)
                        {
                            // The line is quiet now until the next poll, so this is where the logger's
                            // clock is re-read; its reply is back long before the poll goes out.
                            if (LoggerClockDue(_loggerClockReadUtc, DateTime.UtcNow))
                            {
                                ReadLoggerClock();
                            }

                            // Delay polling to ~30 seconds to match device scan interval (INTVL 0,0,30)
                            System.Threading.Tasks.Task.Delay(28000).ContinueWith(_ =>
                            {
                                // The wait is where an old loop outlives a re-init - check before it polls.
                                if (IsStalePoll(generation, "the 28 s wait")) return;
                                var pollReq = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
                                pollReq.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
                                HW_Device.GetLogs(pollReq, r => LogResponseCallBack(r, generation));
                            });
                        }
                        else
                        {
                            // Track how many log entries we're fetching, so the batch is broadcast once the last one is in
                            lock (_logLock)
                            {
                                _pendingLogEntries = response.LogCount;
                                _pendingEntries.Clear();
                            }
                            for (var i = 0; i < response.LogCount; i++)
                            {
                                req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.GetLogs);
                                req.Packet = Common.HydraProtocolHelper.Build_GetChannelLogPacket(i + 1);
                                HW_Device.GetLogs(req, r => HandleLogData(r, generation));
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
                HW_Device.GetLogs(retryReq, r => LogResponseCallBack(r, generation));
            }
        }

        private void LogClearAfterReadCallback(LogsResponse response, int generation)
        {
            Libs.Trace.Tracer.Info("[HYDRA LogClearAfterRead] Result={0}, resuming LOG_COUNT polling", response.Result);
            if (IsStalePoll(generation, "LOG_CLR")) return;
            if (!response.Result)
            {
                // Polling carries on regardless: the entries stay in the logger and are read again with
                // the next scan, and BroadcastEntry drops the ones already sent by their scan time.
                Libs.Trace.Tracer.Info("[HYDRA LogClearAfterRead] LOG_CLR FAILED - the scans just sent are still in the logger; " +
                                       "the next read skips them (last sent scan {0:HH:mm:ss})", _lastBroadcastScanTime);
            }
            // After clearing, resume LOG_COUNT? polling for new scan data
            var req = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.LogCount);
            req.Packet = Common.HydraProtocolHelper.Build_LogCountPacket();
            HW_Device.GetLogs(req, r => LogResponseCallBack(r, generation));
        }

        /// <summary>
        /// MBA-962 (disconnect type 3 — channels): a configured channel is reading its open-input
        /// sentinel. Alerts once, on the way in, naming the channel.
        /// </summary>
        private void NoteChannelDisconnected(int channel)
        {
            if (!_disconnectedChannels.Add(channel)) return;

            Libs.Trace.Tracer.Info("[HYDRA] CH{0} is reading the open-input value - no sensor connected. " +
                                   "It is excluded from the broadcast and from the calibration.", channel);

            HW_Device?.RaiseAlert("ChannelDisconnected",
                string.Format("Channel {0} disconnected - no sensor detected", channel),
                channel.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }

        /// <summary>
        /// The other edge. The alert type is DataRestored and it carries the same channel number
        /// deliberately: the app closes a channel's disconnect range only when it sees a DataRestored
        /// on that exact deviceId:channel pair, and it renders no other restore type.
        /// </summary>
        private void NoteChannelRestored(int channel)
        {
            if (!_disconnectedChannels.Remove(channel)) return;

            Libs.Trace.Tracer.Info("[HYDRA] CH{0} is reading again - sensor reconnected.", channel);

            HW_Device?.RaiseAlert("DataRestored",
                string.Format("Channel {0} reconnected - readings resumed", channel),
                channel.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }

        private void HandleLogData(LogsResponse response)
        {
            HandleLogData(response, System.Threading.Volatile.Read(ref _pollGeneration));
        }

        private void HandleLogData(LogsResponse response, int generation)
        {
            // An outdated loop's entry is dropped whole: its batch count belongs to a loop that no longer
            // exists, and letting it run on would send the LOG_CLR that wipes the live loop's scans.
            if (IsStalePoll(generation, "LOGGED?")) return;

            Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Received LogsResponse: Measurements.Count={0}, Configured Channels.Count={1}, ScanTime={2:HH:mm:ss}",
                response.Measurements.Count, settings.Hydra2type.Channels.Count, response.LogDate);

            for (int m = 0; m < response.Measurements.Count; m++)
            {
                Libs.Trace.Tracer.Info("[HYDRA HandleLogData]   Raw measurement[{0}] = {1}", m, response.Measurements[m]);
            }

            // TODO Change to Device ID
            HC.ProcessResults(response, settings.Hydra2type);

            // The batch goes out once its last entry is in. It used to broadcast only that last entry,
            // so when two scans were waiting the older one was cleared from the logger unsent (MBA-967).
            List<LogsResponse> batch = null;
            int remaining;
            lock (_logLock)
            {
                _pendingEntries.Add(response);
                remaining = --_pendingLogEntries;
                if (remaining <= 0)
                {
                    batch = OrderByScanTime(_pendingEntries);
                    _pendingEntries.Clear();
                }
            }

            if (batch == null)
            {
                Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Holding the broadcast, {0} log entries still pending", remaining);
                return;
            }

            foreach (var entry in batch)
            {
                BroadcastEntry(entry);
            }

            // Clear logs AFTER all entries are read and broadcast, then resume polling
            var clearReq = new Common.API.RemoteProtocolService.LogsRequest(LogsRequest.LogCommands.ClearLogs);
            clearReq.Packet = Common.HydraProtocolHelper.Build_ClearLogsPacket();
            HW_Device.GetLogs(clearReq, r => LogClearAfterReadCallback(r, generation));
        }

        /// <summary>
        /// Oldest scan first. The manual numbers <c>LOGGED? &lt;index&gt;</c> 1..2047 without saying which
        /// end is 1, and the app appends points in arrival order, so the order is taken from the scan
        /// times rather than from the indexes. Stable, so entries without a scan time keep their order.
        /// </summary>
        internal static List<LogsResponse> OrderByScanTime(IEnumerable<LogsResponse> entries)
        {
            return entries.OrderBy(e => e.LogDate).ToList();
        }

        /// <summary>
        /// One logged scan to the clients, with its own time: the logger's scan time moved onto the PC
        /// clock (<see cref="ScanTimeOnPcClock"/>), and the raw scan time for the stale-data check.
        /// <para>
        /// A scan no newer than the last one sent is dropped (<see cref="_lastBroadcastScanTime"/>). A
        /// logger that keeps returning one old entry therefore sends nothing at all, rather than the
        /// repeat the stale-data check used to catch, and the 60 s data watchdog reports it instead.
        /// </para>
        /// </summary>
        private void BroadcastEntry(LogsResponse entry)
        {
            // A failed read has nothing in it. Broadcasting it would tell the watchdog a scan arrived.
            if (entry.Measurements.Count == 0)
            {
                Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Skipping an entry with no measurements (Result={0})", entry.Result);
                return;
            }

            if (entry.LogDate != default(DateTime))
            {
                if (_lastBroadcastScanTime.HasValue && entry.LogDate <= _lastBroadcastScanTime.Value)
                {
                    Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Skipping scan {0:HH:mm:ss}: already sent (last sent {1:HH:mm:ss}) - the previous LOG_CLR did not clear it",
                        entry.LogDate, _lastBroadcastScanTime.Value);
                    return;
                }
                _lastBroadcastScanTime = entry.LogDate;
            }

            var channels = new System.Collections.Generic.List<int>();
            var values = new System.Collections.Generic.List<double>();

            var masterID = settings.Hydra2type.Masters.FirstOrDefault();
            for (int i = 0; i < entry.Measurements.Count && i < settings.Hydra2type.Channels.Count; i++)
            {
                int channel = settings.Hydra2type.Channels[i];
                double rawValue = entry.Measurements[i];

                if (rawValue >= DISCONNECTED_CHANNEL_READING)
                {
                    NoteChannelDisconnected(channel);
                    continue;
                }

                NoteChannelRestored(channel);

                // Apply deviation correction before broadcasting
                var corrected = HC.CalcDeviationForTemperature(rawValue, masterID);
                // Tracer.Info goes to logs\server.log, which is the file publish-logs.ps1 ships off
                // a customer station. This line used to be written a second time to a bare
                // "correction.log" - relative to the working directory, which for the service is
                // system32, and never rotated or deleted. It reached 53 MB on the bench machine
                // holding nothing that was not already here.
                Libs.Trace.Tracer.Info("[HYDRA Correction] CH{0} | Raw={1:F4} | Corrected={2:F4} | Status={3} | MasterID={4}",
                    channel, rawValue, corrected.Item1, corrected.Item2, masterID);
                channels.Add(channel);
                values.Add(corrected.Item1);
            }

            DateTime? scanTime = entry.LogDate == default(DateTime) ? (DateTime?)null : entry.LogDate;
            var measuredAt = ScanTimeOnPcClock(entry.LogDate, _loggerClockOffset);

            Libs.Trace.Tracer.Info("[HYDRA HandleLogData] Broadcasting {0} channels, scan {1:HH:mm:ss} logger / {2} PC: [{3}] values: [{4}]",
                channels.Count,
                entry.LogDate,
                measuredAt.HasValue ? measuredAt.Value.ToString("HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture) : "send time",
                string.Join(",", channels),
                string.Join(",", values.Select(v => v.ToString(System.Globalization.CultureInfo.InvariantCulture))));

            HW_Device.BroadcastAllMeasurements(channels, values, scanTime, measuredAt);
        }
    }

    #endregion

    #endregion
}
