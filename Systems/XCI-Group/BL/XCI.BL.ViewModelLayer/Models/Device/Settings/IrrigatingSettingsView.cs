using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class IrrigatingSettingsView
    {
        public enum MasterZoneSequence
        {
            Parallel = 1,
            MasterFirst = 2,
            MasterLast = 3
        }

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

        [JsonConverter(typeof(StringEnumConverter))]
        public MasterZoneSequence MasterOpenSequence { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public MasterZoneSequence MasterCloseSequence { get; set; }


        public IrrigatingSettingsView(IrrigatingSettings Settings)
        {
            if (Settings == null)
                return;
            IrrigationFactor = Settings.IrrigationFactor;

            ZoneCloseDelay = Settings.ZoneCloseDelay;

            ZoneOpenDelay = Settings.ZoneOpenDelay;

            ZonesOverlapTime = Settings.ZonesOverlapTime;
            MasterCloseSequence = (MasterZoneSequence)Settings.MasterCloseSequence;
            MasterOpenSequence = (MasterZoneSequence)Settings.MasterOpenSequence;
        }

        public IrrigatingSettingsView()
        {

        }

        public static IrrigatingSettingsView CreateDefault()
        {
            return new IrrigatingSettingsView()
            {
                IrrigationFactor = 100,
                MasterCloseSequence = MasterZoneSequence.MasterFirst,
                MasterOpenSequence = MasterZoneSequence.MasterLast,
                ZoneCloseDelay = 10,
                ZoneOpenDelay = 5,
                ZonesOverlapTime = 10
            };
        }
    }
}
