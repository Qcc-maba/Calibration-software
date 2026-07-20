using System;
using System.Collections.Concurrent;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Agilent34401aBLCore : CommonBL.IBLCore
    {
        #region Members

        public Core.ServerCore VCT_Server;

        /// <summary>
        /// One BL per connected 34401A, keyed by serial number, so several multimeters can be used
        /// at once (e.g. as separate master channels). A single shared field would let a second
        /// device overwrite the first and misroute its events.
        /// </summary>
        private readonly ConcurrentDictionary<string, Agilent34401aBL> _blBySN =
            new ConcurrentDictionary<string, Agilent34401aBL>(StringComparer.OrdinalIgnoreCase);
        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region IBLCore Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected && device.SN.Contains("HEWLETT");
            if (isAllowed)
            {
                var bl = _blBySN.GetOrAdd(device.SN, _ => new Device.Agilent34401aBL(this));
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
            Agilent34401aBL bl;
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
            this.DeviceSettings = HardwareBL_Settings.Read();
        }

        public void Stop()
        {
            _blBySN.Clear();
        }

        #endregion
    }
}
