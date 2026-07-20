using Maba.VCT.CommServer.BL.HydaDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.CommServer.CommonBL;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Events;
using System;
using System.Collections.Concurrent;


namespace Maba.VCT.CommServer.BL.HydaDevices.BLCore
{
    public class AdditelBLCore : IBLCore
    {
        #region Members

        public Core.ServerCore VCT_Server;

        /// <summary>
        /// One BL per connected device, keyed by serial number, so several Additel units can run at
        /// once. A single shared field would let a second device overwrite the first and route every
        /// event to whichever connected last.
        /// </summary>
        private readonly ConcurrentDictionary<string, AdditelBL> _blBySN =
            new ConcurrentDictionary<string, AdditelBL>(StringComparer.OrdinalIgnoreCase);
        #endregion

        #region properties

        public HardwareBL_Settings DeviceSettings { get; private set; }

        #endregion

        #region IBLCore Methods

        public bool OnDeviceConnetion(HardwareDeviceHost device)
        {
            bool isAllowed = device != null && device.SN != null && device.IsConnected && device.SN.Contains("TAU");
            if (isAllowed)
            {
                var bl = _blBySN.GetOrAdd(device.SN, _ => new AdditelBL(this));
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
            AdditelBL bl;
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
