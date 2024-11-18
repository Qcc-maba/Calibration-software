using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class ZoneFlowSensorSettingsView
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

        public ZoneFlowSensorSettingsView(ZoneFlowSensorSettings Settings)
        {
            if (Settings == null)
                return;
            TimeFillDelay = Settings.TimeFillDelay;
            ThresholdOverFlow = Settings.ThresholdOverFlow;
            ThresholdUnderFlow = Settings.ThresholdUnderFlow;
            NominalFlow = Settings.NominalFlow;
            LastObservedFlow = Settings.LastObservedFlow;
        }
        public ZoneFlowSensorSettingsView()
        {

        }

        public static ZoneFlowSensorSettingsView CreateDefault()
        {
            return new ZoneFlowSensorSettingsView()
            {
                ThresholdOverFlow = 20,
                ThresholdUnderFlow = 20,
                TimeFillDelay = 600
            };
        }
    }
}
