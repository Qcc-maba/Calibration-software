using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Events
{
    public class EventsBus7E
    {
        #region properties

        public bool AutoHandleNewDevices { get; set; } = false;
        #endregion

        #region events

        public delegate void DeviceConnnectionDelegate(object o, Events.DeviceConnectionEventArgs e);
        public event DeviceConnnectionDelegate DeviceConnnection;

        public delegate void DeviceUnIdentifyConnnectionDelegate(object o, DeviceConnectionEventArgs e);
        public event DeviceUnIdentifyConnnectionDelegate DeviceUnIdentifyConnnection;

        public delegate void DeviceEventDelegate(object o, Events.DeviceEventArgs e);
        public event DeviceEventDelegate DeviceOnIncomingEvent;

        #endregion

        #region Firing events methods

        public void Fire_OnIncomingEvent(object o, Events.DeviceEventArgs e)
        {
            if (DeviceOnIncomingEvent != null)
            {
                DeviceOnIncomingEvent(o, e);
            }
        }

        /// <summary>
        /// Fired for identified devices only (on first connection, re-connection and close)
        /// </summary>
        public void Fire_DeviceConnection(object o, DeviceConnectionEventArgs e)
        {
            if (DeviceConnnection != null)
            {
                DeviceConnnection(o, e);
            }

            if (e.Device.IsConnected && AutoHandleNewDevices)
            {
                e.Handled = true;
            }
        }

        public void Fire_UnIdentifiedConnection(object o, DeviceConnectionEventArgs e)
        {
            if (DeviceUnIdentifyConnnection != null)
            {
                DeviceUnIdentifyConnnection(o, e);
            }
        }

        #endregion
    }
}
