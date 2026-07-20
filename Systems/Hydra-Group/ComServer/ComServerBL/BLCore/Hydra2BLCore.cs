using System;
using System.Collections.Concurrent;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Hydra2BLCore : CommonBL.IBLCore
    {
        #region Members

        internal Core.ServerCore VCT_Server;

        /// <summary>
        /// One BL per connected device, keyed by serial number. A single shared field would let a
        /// second Hydra 2625 overwrite the first, and every event would then be routed to whichever
        /// device connected last.
        /// </summary>
        private readonly ConcurrentDictionary<string, Hydra2DeviceBL> _blBySN =
            new ConcurrentDictionary<string, Hydra2DeviceBL>(StringComparer.OrdinalIgnoreCase);
        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region IBLCore Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected && device.SN.Contains("2625");
            if (isAllowed)
            {
                var bl = _blBySN.GetOrAdd(device.SN, _ => new Device.Hydra2DeviceBL(this));
                if (!ReferenceEquals(device.BL, bl))
                {
                    device.BL = bl;
                    bl.Start(device);
                }
            }
            return (isAllowed);
        }

        public void OnEvent(DeviceEventArgs e)
        {
            var sn = e != null && e.Device != null ? e.Device.SN : null;
            Hydra2DeviceBL bl;
            if (sn != null && _blBySN.TryGetValue(sn, out bl))
            {
                bl.OnEvent(e);
            }
        }

        public void OnWebSocketDeviceConnetion(WebSocketDeviceHost device)
        {
            foreach (var bl in _blBySN.Values)
            {
                bl.Start(device);
            }
        }

        public void Start(Core.ServerCore server)
        {
            this.VCT_Server = server;
            this.DeviceSettings = Settings.HardwareBL_Settings.Read();
        }

        public void Stop()
        {
            _blBySN.Clear();
        }

        #endregion
    }
}
