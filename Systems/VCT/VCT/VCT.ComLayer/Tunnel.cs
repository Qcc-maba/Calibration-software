using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.ComLayer
{
    public class Tunnel
    {
        #region Properties

        // TCP tunnel settings
        public int BacklogClients { get; set; } = 5000;
        public string Name { get; set; }
        public string Address { get; set; } = "";
        public int[] Ports { get; set; }
        public string SettingsName { get; set; } = "";

        // Serial tunnel settings (set SerialPortName to enable serial mode, e.g. "COM3")
        public string SerialPortName { get; set; } = null;
        public int SerialBaudRate { get; set; } = 9600;
        public int SerialTimeout { get; set; } = 100;

        // GPIB (IEEE-488) tunnel settings. Set GpibPrimaryAddress >= 0 to enable GPIB mode
        // (via the NI-488.2 driver / a GPIB-USB adapter). GpibBoardIndex is usually 0.
        public int GpibPrimaryAddress { get; set; } = -1;
        public int GpibBoardIndex { get; set; } = 0;

        // VISA / USBTMC tunnel settings. Set VisaResource to enable VISA mode - either a concrete
        // resource string ("USB0::0x2A8D::0x178B::CN59280205::INSTR") or "AUTO" to take the first USB
        // instrument VISA can see. Needs a VISA runtime (NI-VISA with the USB Passport, or the
        // Keysight IO Libraries Suite). This is the only way to reach an instrument whose sole
        // computer port is USB, such as the Keysight EDU-X 1002A oscilloscope.
        public string VisaResource { get; set; } = null;
        public int VisaTimeoutMs { get; set; } = 5000;

        #endregion

        #region Ctor
        public Tunnel()
        {

        }

        #endregion
    }
}
