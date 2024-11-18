using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class GlobalizationZone
    {
        public int ZoneID { get; set; }
        public string SystemZoneID { get; set; }
        public string DisplayName { get; set; }
        public string DaylightName { get; set; }
        public string StandardName { get; set; }
        public int GMTOffset { get; set; }
        public int ManualOffset { get; set; }
        public bool IsDefault { get; set; }
        public bool IsDaylightTime { get; set; }


        public int GetActualOffset(string SystemZoneID, int Fallbackffset = 0)
        {
            return CalculateActualOffset(this.SystemZoneID, this.GMTOffset);
        }

        public static int CalculateActualOffset(string SystemZoneID, int Fallbackffset = 0)
        {
            if (SystemZoneID == null)
                return Fallbackffset;

            try
            {
                var zone = System.TimeZoneInfo.FindSystemTimeZoneById(SystemZoneID);
                var UTCSPan = zone.IsDaylightSavingTime(DateTime.UtcNow) ? zone.BaseUtcOffset + TimeSpan.FromHours(1) : zone.BaseUtcOffset;

                return (int)UTCSPan.TotalMinutes;
            }
            catch
            {
                return Fallbackffset;
            }
        }
    }
}
