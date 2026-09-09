using Maba.VCT.Core.Device;
using System;

namespace Maba.VCT.Core.Events
{
    /// <summary>
    /// MBA-962: an alert a device's BL raised about itself — the one path a BL has to the WS clients
    /// that does not go through a measurement packet.
    /// <para>
    /// It exists because the BL is the only layer that can see some failures. A channel whose sensor
    /// has been pulled reports the instrument's open-input sentinel: the link is up, the device is
    /// answering, and nothing above the BL can tell that reading apart from a temperature. Before
    /// this, <c>Hydra2DeviceBL</c> dropped those readings with a bare <c>continue</c> and the
    /// calibration carried on with fewer points than the operator had asked for, with nothing on
    /// screen and nothing in the log to say so.
    /// </para>
    /// </summary>
    public class DeviceAlertEventArgs : EventArgs
    {
        /// <summary>The device the alert is about. Never the receiving client — see ServerCore.BroadcastAlertToWebSockets.</summary>
        public HardwareDeviceHost Device { get; private set; }

        /// <summary>One of the AlertTypes the web app declares in its TAlertType union. Inventing a new
        /// one silently loses the alert: the app narrows to that union and renders nothing else.</summary>
        public string AlertType { get; private set; }

        public string Message { get; private set; }

        /// <summary>The channel number as text, or "ALL" for a device-wide alert. The app pairs a
        /// ChannelDisconnected with a later DataRestored on the SAME deviceId:channel key, so a restore
        /// that does not carry the channel it belongs to leaves the disconnect range open for good.</summary>
        public string Channel { get; private set; }

        public DeviceAlertEventArgs(HardwareDeviceHost device, string alertType, string message, string channel)
        {
            this.Device = device;
            this.AlertType = alertType;
            this.Message = message;
            this.Channel = channel;
        }
    }
}
