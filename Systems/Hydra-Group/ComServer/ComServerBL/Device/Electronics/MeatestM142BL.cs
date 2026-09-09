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
    /// Meatest M-142 multifunction calibrator. NOT yet verified against hardware — the commands and
    /// reply shapes come from the official manual (meatest.com, m142m.pdf).
    /// <para>
    /// ⚠️⚠️ THIS INSTRUMENT SOURCES REAL VOLTAGE AND CURRENT, AND WITH THE 50-TURN COIL OPTION
    /// (<c>OUTP:ISEL HI50</c>) REACHES 1000 A. ⚠️⚠️ The rule is the one every source here follows —
    /// see <see cref="Datron9100BL"/> and <see cref="Fluke5522aBL"/>: the terminals are connected
    /// only by an explicit commanded calibration target through
    /// <see cref="MeatestM142Commands.BuildOutputOn"/>. The init below and the read loop never issue
    /// it; the init drives the instrument the other way, into a disconnected output.
    /// </para>
    /// <para>
    /// <b>What makes this device different from the other sources.</b> The M-142 is also a METER. It
    /// has an internal multimeter, so unlike the Datron 9100 and the Fluke 5522A — which can only
    /// echo their own setpoint — this one can report a value it actually measured. The read loop
    /// therefore asks <c>MEAS:CONF?</c> first: if the meter is configured it broadcasts <c>MEAS?</c>,
    /// a genuine measurement; if the meter is OFF it falls back to the source setpoint, which is
    /// still what a calibration compares a DUT against.
    /// </para>
    /// <para>
    /// Interfaces: GPIB (factory address 2) and RS-232, both standard. RS-232 is 8-N-1 at
    /// 150-19200 baud selected from the instrument menu, and it takes a STRAIGHT 1:1 cable — NOT the
    /// null-modem the Fluke 5522A needs. Getting that backwards produces the same total silence the
    /// 5522A gave us before its cable was swapped.
    /// </para>
    /// See docs/devices/electronics/Meatest-M142/protocol.md.
    /// </summary>
    public class MeatestM142BL : CommonBL.BaseBLDevice
    {
        #region CONSTANTS

        public const int STATE_MACHINE__InitSystem = 1;
        public const int STATE_MACHINE__Read = 2;

        public CommonBL.SingleState StateMachine_InitSystem { get; private set; }
        public CommonBL.SingleState StateMachine_Read { get; private set; }

        private const int MaxConsecutiveFailures = 10;

        /// <summary>Where the read cycle currently is. One outstanding query at a time, as always.</summary>
        private enum ReadPhase
        {
            /// <summary>OUTP? - are the terminals connected. Observational only.</summary>
            OutputState,
            /// <summary>MEAS:CONF? - is the internal meter measuring, and what.</summary>
            MeterConfig,
            /// <summary>MEAS? - a real measured value.</summary>
            MeasuredValue,
            /// <summary>SOUR:&lt;function&gt;? - the setpoint, used when the meter is off.</summary>
            Setpoint,
        }

        #endregion

        #region properties

        private readonly HardwareBL_Settings settings;
        private int _consecutiveFailures;

        private ReadPhase _phase;

        /// <summary>The last MEAS:CONF? answer, kept so the value phase knows how to label the reading.</summary>
        private string _meterMode = MeatestM142Readings.MeterOff;

        #endregion

        #region ctor

        public MeatestM142BL(MeatestM142BLCore parent) : base(parent)
        {
            settings = parent.DeviceSettings;
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

        #region state machine :: InitSystem

        /// <summary>
        /// Drives the calibrator to a known, disconnected state. Every step is either read-only or
        /// moves the instrument AWAY from sourcing - see <see cref="MeatestM142Commands.InitSequence"/>.
        /// </summary>
        private CommonBL.SingleState.StepWorkResponses StateWork__InitSystem(CommonBL.SingleState singleState)
        {
            var sequence = MeatestM142Commands.InitSequence;
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

        #region state machine :: Read (output state -> meter config -> measurement or setpoint)

        private CommonBL.SingleState.StepWorkResponses StateWork__Read(CommonBL.SingleState singleState)
        {
            switch (singleState.CurrentStep)
            {
                case 0:
                    QueryOutputState();
                    return CommonBL.SingleState.StepWorkResponses.Skip2NextStep;
            }
            return CommonBL.SingleState.StepWorkResponses.StateFinished;
        }

        /// <summary>
        /// Asks whether the terminals are connected. Purely observational - the BL reports this and
        /// never changes it - but on an instrument that can drive 1000 A through a coil it belongs in
        /// the log beside every reading.
        /// </summary>
        private void QueryOutputState()
        {
            Send(ReadPhase.OutputState, HydraProtocolHelper.Build_M142_QueryOutput());
        }

        private void Send(ReadPhase phase, HardwarePacket packet)
        {
            _phase = phase;
            var req = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            req.Packet = packet;
            HW_Device.GetLogs(req, ReadCallback);
        }

        private void ReadCallback(LogsResponse response)
        {
            var phase = _phase;

            // Read from the raw text: OUTP? answers the word ON/OFF and MEAS:CONF? answers a mode
            // token, neither of which any shared numeric branch can turn into a reading.
            var reply = response != null && response.Result ? response.RawText : null;

            if (string.IsNullOrEmpty(reply))
            {
                _consecutiveFailures++;
                Continue();
                return;
            }

            switch (phase)
            {
                case ReadPhase.OutputState:
                    var live = MeatestM142Readings.IsOutputLive(reply);
                    Libs.Trace.Tracer.Info("[MEATEST M-142] {0}: output terminals are {1}.",
                        HW_Device.SN, live ? "CONNECTED" : "disconnected");
                    Send(ReadPhase.MeterConfig, HydraProtocolHelper.Build_M142_QueryMeasureConfig());
                    return;

                case ReadPhase.MeterConfig:
                    _meterMode = MeatestM142Readings.NormalizeMeterMode(reply);
                    if (MeatestM142Readings.IsMeterOff(reply))
                    {
                        // No measurement to be had; report what the calibrator is set to source.
                        Send(ReadPhase.Setpoint, HydraProtocolHelper.Build_M142_QuerySetpoint(CurrentSensor()));
                    }
                    else
                    {
                        Send(ReadPhase.MeasuredValue, HydraProtocolHelper.Build_M142_Measure());
                    }
                    return;

                case ReadPhase.MeasuredValue:
                case ReadPhase.Setpoint:
                    Publish(reply, phase);
                    Continue();
                    return;
            }

            Continue();
        }

        private void Publish(string reply, ReadPhase phase)
        {
            double value;
            if (!MeatestM142Readings.TryParseValue(reply, out value))
            {
                _consecutiveFailures++;
                return;
            }

            _consecutiveFailures = 0;

            // The broadcast units come from the configured sensor (ServerCore resolves them by SN),
            // so log the meter's own idea of the unit too: a mismatch between the two is exactly the
            // kind of misconfiguration that otherwise shows up as a plausible-looking wrong number.
            Libs.Trace.Tracer.Info("[MEATEST M-142] {0}: {1} = {2} ({3}).",
                HW_Device.SN,
                phase == ReadPhase.MeasuredValue ? "measured" : "setpoint",
                value,
                phase == ReadPhase.MeasuredValue
                    ? MeatestM142Readings.UnitsForMeterMode(_meterMode)
                    : HardwareBL_Settings.UnitsForSensor(CurrentSensor()));

            HW_Device.BroadcastAllMeasurements(new List<int> { 1 }, new List<double> { value });
        }

        /// <summary>
        /// The configured sensor for this device, or null when the settings say nothing. Resolved by
        /// SN through the same family lookup the rest of the server uses, so the setpoint query and
        /// the units the broadcast is labelled with come from one place.
        /// </summary>
        private SensorType CurrentSensor()
        {
            if (settings == null)
                return null;

            var family = settings.ResolveFamilyBySN(HW_Device.SN);
            return family == null ? null : family.Sensor;
        }

        private void Continue()
        {
            if (HW_Device == null || !HW_Device.IsConnected)
                return;

            if (_consecutiveFailures >= MaxConsecutiveFailures)
            {
                Libs.Trace.Tracer.Info(
                    "[MEATEST M-142] {0} consecutive failed reads on {1} - stopping until reconnect.",
                    _consecutiveFailures, HW_Device.SN);
                return;
            }

            QueryOutputState();
        }

        #endregion
    }

    /// <summary>
    /// The single source of truth for every command the M-142 BL sends. Raw strings live in
    /// <see cref="HydraProtocolHelper"/>'s "Meatest M-142" region; this class composes them.
    /// <para>
    /// ⚠️ <see cref="BuildOutputOn"/> connects the output terminals for real. The init sequence omits
    /// it by design, and so does the read loop.
    /// </para>
    /// </summary>
    public static class MeatestM142Commands
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
        /// Ordered init sequence. *RST returns the calibrator to its power-up state, which has the
        /// output disconnected; the explicit OUTP OFF that follows makes the de-energised end state a
        /// stated intention rather than a side effect of the reset. Nothing here can source anything.
        /// </summary>
        public static readonly InitCommand[] InitSequence =
        {
            new InitCommand("reset to power-up state (*RST)", () => HydraProtocolHelper.Build_M142_Reset()),
            new InitCommand("clear status and error queue (*CLS)", () => HydraProtocolHelper.Build_M142_ClearStatus()),
            new InitCommand("disconnect the output terminals (OUTP OFF)", () => HydraProtocolHelper.Build_M142_OutputOff()),
        };

        // -- Read-only -----------------------------------------------------------
        public static Common.HardwarePacket BuildIdentify() { return HydraProtocolHelper.Build_M142_Identify(); }
        public static Common.HardwarePacket BuildOperationComplete() { return HydraProtocolHelper.Build_M142_OperationComplete(); }
        public static Common.HardwarePacket BuildQueryOutput() { return HydraProtocolHelper.Build_M142_QueryOutput(); }
        public static Common.HardwarePacket BuildQueryFunction() { return HydraProtocolHelper.Build_M142_QueryFunction(); }
        public static Common.HardwarePacket BuildMeasure() { return HydraProtocolHelper.Build_M142_Measure(); }
        public static Common.HardwarePacket BuildQueryMeasureConfig() { return HydraProtocolHelper.Build_M142_QueryMeasureConfig(); }
        public static Common.HardwarePacket BuildQuerySetpoint(SensorType sensor) { return HydraProtocolHelper.Build_M142_QuerySetpoint(sensor); }

        // -- Safe state changes --------------------------------------------------
        public static Common.HardwarePacket BuildReset() { return HydraProtocolHelper.Build_M142_Reset(); }
        public static Common.HardwarePacket BuildClearStatus() { return HydraProtocolHelper.Build_M142_ClearStatus(); }
        public static Common.HardwarePacket BuildOutputOff() { return HydraProtocolHelper.Build_M142_OutputOff(); }

        // -- Setpoints: they select a value, they do not connect the terminals ----
        public static Common.HardwarePacket BuildSetVoltage(double volts) { return HydraProtocolHelper.Build_M142_SetVoltage(volts); }
        public static Common.HardwarePacket BuildSetCurrent(double amps) { return HydraProtocolHelper.Build_M142_SetCurrent(amps); }
        public static Common.HardwarePacket BuildSetResistance(double ohms) { return HydraProtocolHelper.Build_M142_SetResistance(ohms); }
        public static Common.HardwarePacket BuildSetCapacitance(double farads) { return HydraProtocolHelper.Build_M142_SetCapacitance(farads); }
        public static Common.HardwarePacket BuildSetFrequency(double hertz) { return HydraProtocolHelper.Build_M142_SetFrequency(hertz); }

        // -- Energises the terminals ---------------------------------------------
        /// <summary>
        /// ⚠️ Connects the selected value to the output terminals for real. With the 50-turn coil
        /// option this reaches 1000 A. Only for a commanded calibration target, always paired with
        /// <see cref="BuildOutputOff"/>.
        /// </summary>
        public static Common.HardwarePacket BuildOutputOn() { return HydraProtocolHelper.Build_M142_OutputOn(); }
    }
}
