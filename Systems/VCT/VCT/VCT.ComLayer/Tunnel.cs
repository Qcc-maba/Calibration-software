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

        #endregion

        #region Ctor
        public Tunnel()
        {

        }

        #endregion
    }
}
