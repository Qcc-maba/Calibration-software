using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone
{
    public class ZoneFlowSensorSettings
    {

        //water settings
        /// <summary>
        /// (Seconds) Time takes to Zone's pipe to be filled. Ignore flow alerts while this time.
        /// </summary>
        public int TimeFillDelay { get; set; }

        //Hige/Low flow alerts
        /// <summary>
        /// (Percent)
        /// </summary>
        public int ThresholdOverFlow { get; set; }

        /// <summary>
        /// (Percent)
        /// </summary>
        public int ThresholdUnderFlow { get; set; }

        public decimal? NominalFlow { get; set; }
        public decimal? LastObservedFlow { get; set; }
    }
}
