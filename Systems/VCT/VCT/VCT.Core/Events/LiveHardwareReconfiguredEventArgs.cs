using System;

namespace Maba.VCT.Core.Events
{
    /// <summary>
    /// MBA-974: raised when a WebSocket client's SensorsAssociation/LoggerConfiguration message
    /// actually changed a live device's channels, rate or interval in
    /// <c>HardwareBL_Settings.ApplyWebSocketConfig</c>. That call only updates the in-memory
    /// settings object - the physical instrument is otherwise only ever told its scan configuration
    /// once, at connect time. This event is the seam a listener (ServerCore) uses to push the new
    /// configuration down to whichever live device is actually driving <see cref="FamilyKey"/>.
    /// </summary>
    public class LiveHardwareReconfiguredEventArgs : EventArgs
    {
        /// <summary>The HardwareBL_Settings family the change applies to (e.g. "Hydra2").</summary>
        public string FamilyKey { get; private set; }

        /// <summary>Human-readable cause, for the re-init's own log line.</summary>
        public string Reason { get; private set; }

        public LiveHardwareReconfiguredEventArgs(string familyKey, string reason)
        {
            FamilyKey = familyKey;
            Reason = reason;
        }
    }
}
