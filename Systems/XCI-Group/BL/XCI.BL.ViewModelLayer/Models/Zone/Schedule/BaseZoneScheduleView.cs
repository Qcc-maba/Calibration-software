using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using static Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone.Schedule
{
    public class BaseZoneScheduleView
    {
        #region Properties

        public string SN { get; set; }
        public int ZoneNumber { get; set; }

        public string ScheduleTypeName { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public ScheduleTypes ScheduleType { get; set; }

        /// <summary>
        /// (Seconds)
        /// </summary>
        public int? MaxCycleTime { get; set; }

        /// <summary>
        /// (Seconds)
        /// </summary>
        public int? MaxSoakTime { get; set; }

        #endregion

        public static ZoneIrrigationScheduleView GetWeeklyScheduleView(IrrigationSchedule Schedule, DaySettings[] DaySettings)
        {
            //make sure it is 7 Days
            var daySettings_new = new DaySettings[7].Select(u => new DaySettings()).ToArray();

            foreach (var item in DaySettings)
            {
                daySettings_new[item.DayIndex] = item;
            }

            var ZoneView = new ZoneIrrigationScheduleView();
            if (Schedule == null || Schedule.ScheduleItems == null || Schedule.ScheduleItems.Count == 0)
                return ZoneView;
            ZoneView.TitleDays = new ScheduleDayView[7];

            for (int i = 0; i < 7; i++)
            {
                ZoneView.TitleDays[i] = new ScheduleDayView() { DayNumber = (byte)(i), IsAllowedDay = daySettings_new[i].IrrigationAllowed };
            }

            ZoneView.TotalWeeklyDays = Schedule.ScheduleItems
                                .Where(d => d.Quantity > 0 || d.StartTime > 0)
                                .GroupBy(d => d.DayNum)
                                .Count();

            ZoneView.ScheduleType = (ScheduleTypes)Schedule.ScheduleType;

            int totalWeeklySeconds = 0;

            #region Bulid Days

            var _rows = new List<ZoneIrrigationScheduleRow>();

            foreach (var r in Schedule.ScheduleItems.GroupBy(s => s.StartTime))
            {
                var row = new ZoneIrrigationScheduleRow()
                {
                    Time = r.Key,
                    Days = new ZoneIrrigationScheduleDay[7]
                };

                for (int i = 0; i < row.Days.Length; i++)
                {
                    row.Days[i] = new ZoneIrrigationScheduleDay()
                    {
                        Day = ZoneView.TitleDays[i].DayNumber,
                        Duration = 0,
                        Quantity = 0
                    };
                }

                foreach (var d in r)
                {
                    row.Days[d.DayNum].Duration = d.Time.GetValueOrDefault(0);
                    row.Days[d.DayNum].Quantity = d.Quantity.GetValueOrDefault(0);

                    totalWeeklySeconds += d.Quantity.GetValueOrDefault(0);
                }


                _rows.Add(row);
            }

            ZoneView.Rows = _rows.OrderBy(t=>t.Time).ToArray();

            #endregion

            #region Update times

            foreach (var item in Schedule.ScheduleItems)
            {
                var itemRow = ZoneView.Rows.FirstOrDefault(s => s.Time == item.StartTime);
                var itemDay = itemRow.Days.FirstOrDefault(d => d.Day == item.DayNum);
                itemDay.Duration = item.Time.GetValueOrDefault(0);
                itemDay.Quantity = item.Quantity.GetValueOrDefault(0);
            }

            #endregion

            #region Max && Total

            ZoneView.TotalWeeklyMinutes = totalWeeklySeconds / 60;
            //ZoneView.
            #endregion

            return ZoneView;

        }

        public static ZoneIrrigationScheduleDailyView GetDailyScheduleView(List<IrrigationScheduleItem> ScheduleItems, ScheduleTypes scheduleType)
        {
            var Daily = new ZoneIrrigationScheduleDailyView();

            #region GetStartTime

            List<DailyStartTime> DailyStartTimes = ScheduleItems
                                                        .OrderBy(u => u.StartTime)
                                                        .GroupBy(g => g.StartTime)
                                                        .Select(u => new DailyStartTime()
                                                        {
                                                            Time = u.Key
                                                        })
                                                        .ToList();

            var countTime = DailyStartTimes.Count;
            Daily.ScheduleType = scheduleType;
            #endregion

            #region OrderTimes

            foreach (var item in DailyStartTimes)
            {
                var zone_db = ScheduleItems.FirstOrDefault(d => d.StartTime == item.Time);
                if (zone_db != null)
                {
                    item.Duration = zone_db.Time;
                    item.Quantity = zone_db.Quantity;
                }
            }

            
            #endregion

            Daily.StartTimes = DailyStartTimes.ToArray();
            return Daily;

        }
    }
    
}
