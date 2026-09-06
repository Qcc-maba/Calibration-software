using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Siglent SDG6052X arbitrary waveform generator over USBTMC.
    /// Verified live 2026-09-01 against "Siglent Technologies,SDG6052X,SDG6XEBD4R0879,6.01.01.35R5B1".
    /// <para>
    /// ⚠️ This is a SOURCE, not a logger, and the operator drives it from the front panel. Two rules
    /// follow, and both are deliberate:
    /// </para>
    /// <list type="bullet">
    /// <item><b>The init never resets the instrument.</b> On the SDG <c>*RST</c> means "restore
    /// default settings" - it would wipe whatever the operator has dialled in. Init identifies the
    /// unit and reads its state back, nothing more.</item>
    /// <item><b>The init never enables an output.</b> A generator output energises a cable. It is
    /// turned on only by an explicit commanded target through
    /// <see cref="Sdg6052xCommands.BuildOutputOn"/>, never by the loop below.</item>
    /// </list>
    /// <para>
    /// The read loop therefore reports the generator's own setpoint - the frequency it is configured
    /// to produce - which is what a calibration compares a counter's reading against.
    /// </para>
    /// See docs/devices/electronics/Siglent-SDG6052X/protocol.md.
    /// </summary>
    public class Sdg6052xBL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        private const int MaxConsecutiveFailures = 10;

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;

        /// <summary>The output channels to report, validated against what this model has.</summary>
        private readonly List<int> channels;

        private int _channelIndex;
        private int _consecutiveFailures;

        #endregion

        #region ctor

        public Sdg6052xBL(Sdg6052xBLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;

            var configured = settings.Sdg6052x != null ? settings.Sdg6052x.Channels : null;
            channels = configured != null
                ? configured.Where(Sdg6052xReplies.IsValidChannel).Distinct().OrderBy(c => c).ToList()
                : new List<int>();

            if (channels.Count == 0)
                channels.Add(1);
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

            if (this.StateMachine_Read == null)
            {
                this.StateMachine_Read = new CommonBL.SingleState(STATE_MACHINE__Read, "Read")
                {
                    Action_DoWork = StateWork__Read
                };
            }

            this.StateMachine_InitSystem.IsActive = true;
            this.StateMachine_Read.IsActive = true;

            var states = new CommonBL.SingleState[]
            {
                this.StateMachine_InitSystem,
                this.StateMachine_Read,
            };

            return states.OrderBy(s => s.State).ToArray();
        }

        protected override bool OnStepStart(DeviceSteps step)
        {
            switch (step)
            {
                case DeviceSteps.Start: return true;
                case DeviceSteps.Routine: return false;
                case DeviceSteps.Close: return true;
            }
            return false;
        }

        public override void OnEvent(DeviceEventArgs e)
        {
            base.OnEvent(e);
        }

        #endregion

        #region state machine :: InitSystem (read-only - never resets, never energises)

        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var sequence = Sdg6052xCommands.InitSequence;
            int step = singleState.CurrentStep;

            if (step >= 0 && step < sequence.Length)
            {
                var req = new InitSystemRequest();
                req.Packet = sequence[step].Build();
                HW_Device.Reset(req);
                return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }

            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        #endregion

        #region state machine :: Read (reports the configured setpoint)

        private CommonBL.SingleState.StepWorkResponses StateWork__Read(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    _channelIndex = 0;
                    QueueBasicWaveQuery(channels[_channelIndex]);
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        private void QueueBasicWaveQuery(int channel)
        {
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = Sdg6052xCommands.BuildQueryBasicWave(channel);
            HW_Device.GetLogs(req, BasicWaveCallback);
        }

        private void BasicWaveCallback(LogsResponse response)
        {
            var channel = channels[_channelIndex];

            try
            {
                // The raw reply is what matters here, not response.Measurements: the shared numeric
                // paths cannot read "FRQ,1000HZ" and must not be relied on for this instrument.
                var reply = response != null ? response.RawText : null;
                double value;

                if (!string.IsNullOrEmpty(reply) &&
                    Sdg6052xCommands.TryReadSetpoint(reply, settings.Sdg6052x, out value))
                {
                    _consecutiveFailures = 0;
                    HW_Device.BroadcastAllMeasurements(new List<int> { channel }, new List<double> { value });
                }
                else
                {
                    _consecutiveFailures++;
                }
            }
            finally
            {
                RequestNext();
            }
        }

        private void RequestNext()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[SDG6052X] {0} consecutive failed reads on {1} - stopping until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            _channelIndex = (_channelIndex + 1) % channels.Count;
            QueueBasicWaveQuery(channels[_channelIndex]);
        }

        #endregion
    }

    /// <summary>
    /// The single source of truth for every command the SDG6052X BL sends. Raw strings live in
    /// <see cref="HydraProtocolHelper"/>'s "Siglent SDG6052X" region; this class composes them.
    /// <para>
    /// ⚠️ <see cref="BuildOutputOn"/> energises a physical output. The init sequence deliberately
    /// omits it, and so does the read loop.
    /// </para>
    /// </summary>
    public static class Sdg6052xCommands
    {
        /// <summary>One labelled init command: a human-readable purpose plus the packet it builds.</summary>
        public sealed class InitCommand
        {
            public string Purpose { get; private set; }
            public Func<Common.HardwarePacket> Build { get; private set; }

            public InitCommand(string purpose, Func<Common.HardwarePacket> build)
            {
                Purpose = purpose;
                Build = build;
            }
        }

        /// <summary>
        /// Ordered init sequence. Read-only by design: no *RST (which on the SDG restores factory
        /// defaults and would discard the operator's front-panel setup) and no output enable.
        /// </summary>
        public static readonly InitCommand[] InitSequence =
        {
            new InitCommand("identify (*IDN?)", () => HydraProtocolHelper.Build_Sdg_Identify()),
            new InitCommand("drain the error queue (SYST:ERR?)", () => HydraProtocolHelper.Build_Sdg_ReadError()),
        };

        // ── Read-only ────────────────────────────────────────────────────────────
        public static Common.HardwarePacket BuildIdentify() { return HydraProtocolHelper.Build_Sdg_Identify(); }
        public static Common.HardwarePacket BuildReadError() { return HydraProtocolHelper.Build_Sdg_ReadError(); }
        public static Common.HardwarePacket BuildQueryBasicWave(int channel) { return HydraProtocolHelper.Build_Sdg_QueryBasicWave(channel); }
        public static Common.HardwarePacket BuildQueryOutput(int channel) { return HydraProtocolHelper.Build_Sdg_QueryOutput(channel); }

        // ── Configuration (changes the instrument, but does not energise it) ──────
        public static Common.HardwarePacket BuildSetWaveType(int channel, string waveType) { return HydraProtocolHelper.Build_Sdg_SetWaveType(channel, waveType); }
        public static Common.HardwarePacket BuildSetFrequency(int channel, double hertz) { return HydraProtocolHelper.Build_Sdg_SetFrequency(channel, hertz); }
        public static Common.HardwarePacket BuildSetAmplitude(int channel, double vpp) { return HydraProtocolHelper.Build_Sdg_SetAmplitude(channel, vpp); }
        public static Common.HardwarePacket BuildSetOffset(int channel, double volts) { return HydraProtocolHelper.Build_Sdg_SetOffset(channel, volts); }
        public static Common.HardwarePacket BuildSetLoad(int channel, string load) { return HydraProtocolHelper.Build_Sdg_SetLoad(channel, load); }

        // ── ⚠️ Energises / de-energises the output ───────────────────────────────
        public static Common.HardwarePacket BuildOutputOn(int channel) { return HydraProtocolHelper.Build_Sdg_OutputOn(channel); }
        public static Common.HardwarePacket BuildOutputOff(int channel) { return HydraProtocolHelper.Build_Sdg_OutputOff(channel); }

        /// <summary>
        /// Pulls the value this generator is configured to produce out of a BSWV reply. Which
        /// parameter that is depends on what the family is set up to report: a frequency source
        /// reports FRQ, a voltage source reports AMP.
        /// </summary>
        public static bool TryReadSetpoint(string basicWaveReply, HardwareBL_DeviceType family, out double value)
        {
            var parameters = Sdg6052xReplies.ParseParameters(basicWaveReply);

            var measureType = family != null && family.Sensor != null
                ? family.Sensor.MeasureType
                : SensorType.MeasureTypes.Frequency;

            switch (measureType)
            {
                case SensorType.MeasureTypes.VoltagePP:
                case SensorType.MeasureTypes.VoltageRMS:
                case SensorType.MeasureTypes.VoltageDC:
                    return Sdg6052xReplies.TryGetNumeric(parameters, "AMP", out value);
                case SensorType.MeasureTypes.Frequency:
                default:
                    return Sdg6052xReplies.TryGetNumeric(parameters, "FRQ", out value);
            }
        }
    }
}
