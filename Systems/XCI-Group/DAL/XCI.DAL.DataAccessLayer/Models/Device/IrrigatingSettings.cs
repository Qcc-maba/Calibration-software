using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class IrrigatingSettings
    {
        /// <summary>
        /// (%Percent)
        /// </summary>
        public int IrrigationFactor { get; set; }

        /// <summary>
        /// Seconds
        /// </summary>
        public int ZoneCloseDelay { get; set; }
        /// <summary>
        /// Seconds
        /// </summary>
        public int ZoneOpenDelay { get; set; }
        /// <summary>
        /// Seconds
        /// </summary>
        public int ZonesOverlapTime { get; set; }

      
        public byte MasterOpenSequence { get; set; }


        public byte MasterCloseSequence { get; set; }
    }
}
