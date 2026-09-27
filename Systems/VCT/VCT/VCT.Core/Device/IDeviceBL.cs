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
    }
}
