using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Concurrent;

namespace Maba.VCT.CommServer.CommonBL
{
    /// <summary>
    /// Shared plumbing for the per-instrument-family BL cores (Hydra, Agilent, TTI, ...).
    /// <para>
    /// A subclass only declares which serial numbers belong to its family
    /// (<see cref="DeviceIdToken"/>) and how to build a BL for one device
    /// (<see cref="CreateDeviceBL"/>); everything else — claiming devices, tracking them and
    /// routing events — is handled here.
    /// </para>
    /// <para>
    /// One BL is kept PER DEVICE, keyed by serial number, so several instruments of the same family
    /// can run at once. A single shared field (the previous design) let a second device overwrite
    /// the first, after which every event went to whichever device connected last.
    /// </para>
    /// See docs/architecture.md.
    /// </summary>
    public abstract class BaseBLCore : IBLCore
    {
        #region Members

        private readonly ConcurrentDictionary<string, BaseBLDevice> _blBySN =
            new ConcurrentDictionary<string, BaseBLDevice>(StringComparer.OrdinalIgnoreCase);

        #endregion

        #region Properties

        /// <summary>The server hosting this core.</summary>
        public Core.ServerCore VCT_Server { get; private set; }

        /// <summary>Per-instrument-type configuration (channels, rate, sensor, masters).</summary>
        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region To implement per family

        /// <summary>
        /// Substring of the device serial number that identifies this family, as returned by the
        /// identification reply (e.g. "2625", "HEWLETT").
        /// </summary>
        protected abstract string DeviceIdToken { get; }

        /// <summary>Creates the business logic for one newly connected device of this family.</summary>
        protected abstract BaseBLDevice CreateDeviceBL();

        #endregion

        #region IBLCore

        public virtual void Start(Core.ServerCore server)
        {
            VCT_Server = server;
            DeviceSettings = HardwareBL_Settings.Read();
        }

        public virtual void Stop()
        {
            _blBySN.Clear();
        }

        public virtual bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected
                             && device.SN.Contains(DeviceIdToken);
            if (!isAllowed)
                return false;

            var bl = _blBySN.GetOrAdd(device.SN, _ => CreateDeviceBL());
            if (!ReferenceEquals(device.BL, bl))
            {
                device.BL = bl;
                bl.Start(device);
            }
            return true;
        }

        public virtual void OnEvent(DeviceEventArgs e)
        {
            var sn = e != null && e.Device != null ? e.Device.SN : null;
            BaseBLDevice bl;
            if (sn != null && _blBySN.TryGetValue(sn, out bl))
            {
                bl.OnEvent(e);
            }
        }

        public virtual void OnWebSocketDeviceConnetion(WebSocketDeviceHost device)
        {
            foreach (var bl in _blBySN.Values)
            {
                bl.Start(device);
            }
        }

        #endregion
    }
}
