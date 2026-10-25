using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace Maba.VCT.Core.Device
{
    /// <summary>
    /// The business logic attached to one device host — it drives the instrument (init, configure,
    /// acquire) and reacts to incoming packets. Implemented by CommonBL.BaseBLDevice.
    /// </summary>
    public interface IDeviceBL
    {
        void Start(IDeviceHost device);
        void OnTimer();
        bool OnConnection(bool state);
        void OnEvent(Events.DeviceEventArgs e);

        /// <summary>
        /// MBA-974: the <c>HardwareBL_Settings</c> family this BL drives (e.g. "Hydra2"), or null
        /// when the BL has none - lets a live settings change be routed back to the one BL instance
        /// actually driving that family, without every BL needing to know about settings routing
        /// itself. See <c>HardwareBL_Settings.ResolveLiveFamilyKey</c>.
        /// </summary>
        string SettingsFamily { get; }

        /// <summary>
        /// MBA-967: whether this BL runs a scan that <see cref="StopScanning"/> can stop. Asked
        /// before the host touches anything, so a device whose BL cannot stop is really left as it
        /// was - its queued requests and its watchdog state included.
        /// </summary>
        bool CanStopScanning { get; }

        /// <summary>
        /// MBA-967: the operator's "stop scan". Stops whatever this BL is running against the
        /// instrument - its init sequence and any polling loop - and tells the instrument to stop.
        /// Called only on the device tick thread (<c>HardwareDeviceHost.StopScanning</c>, and its
        /// reconnect while stopped). Returns false when the BL has no scan to stop, so the host knows
        /// not to treat it as stopped.
        /// </summary>
        bool StopScanning(string reason);
    }
}
