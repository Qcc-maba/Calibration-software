using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net.WebSockets;
using System.Runtime;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.BL.HydraDevices.BLCore
{
    public class Hydra3BLCore : CommonBL.IBLCore
    {
        #region Members

        internal Core.ServerCore VCT_Server;

        /// <summary>
        /// One BL per connected device, keyed by serial number, so several Hydra 2638 units can run
        /// at once. A single shared field would let a second device overwrite the first and route
        /// every event to whichever connected last.
        /// </summary>
        private readonly ConcurrentDictionary<string, Hydra3DeviceBL> _blBySN =
            new ConcurrentDictionary<string, Hydra3DeviceBL>(StringComparer.OrdinalIgnoreCase);

        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region Public Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.SN.Contains("2638") && device.IsConnected;
            if (isAllowed)
            {
                var bl = _blBySN.GetOrAdd(device.SN, _ => new Device.Hydra3DeviceBL(this));
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
            Hydra3DeviceBL bl;
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

        public void Start(ServerCore server)
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
