using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class ZoneIrrigationSuggestionView
    {

        [JsonConverter(typeof(StringEnumConverter))]
        public ScheduleTypes ScheduleType { get; set; }
        public DateTime? LastSuggestionAcceptedDate { get; set; }
        public bool IsAccepted { get; set; }

        public DateTime? LastSuggestionDate { get; set; }
        public int Suggestion_TotalWeeklyMinutes { get; set; }
        public int Suggestion_TotalWeeklyDays { get; set; }

        public int Suggestion_TotalMonthMinutes { get; set; }
        public int Suggestion_MaximumCycleMinutes { get; set; }
        //
        public int Suggestion_RunTimeDaily { get; set; }
        public int Suggestion_SoakTimeMinutes { get; set; }
        public int Number { get; set; }

        public int Current_TotalWeeklyMinutes { get; set; }
        public byte Current_WateringDays { get; set; }
       // public int Current_RunTimeDaily { get; set; }
        public int? MaxCycleTime { get; set; }

        /// <summary>
        /// (Seconds)
        /// </summary>
        public int? MaxSoakTime { get; set; }



        public ZoneIrrigationSuggestionView()
        {
                
        }

        public ZoneIrrigationSuggestionView(ZoneIrrigationSuggestion z , ZoneIrrigationAccumulate setting )
        {
            if (z == null)
                return;
            LastSuggestionAcceptedDate = z.LastSuggestionAcceptedDate;
            //IsAccepted = z.IsAccepted;
            LastSuggestionDate = z.LastSuggestionDate;
            Suggestion_MaximumCycleMinutes = z.Suggestion_MaximumCycleMinutes;
            Suggestion_TotalWeeklyDays = z.Suggestion_TotalWeeklyDays;
            Suggestion_TotalWeeklyMinutes = z.Suggestion_TotalWeeklyMinutes;
            Suggestion_SoakTimeMinutes = z.Suggestion_SoakTimeMinutes;
            Suggestion_RunTimeDaily = z.Suggestion_RunTimeDaily;
            Suggestion_TotalMonthMinutes = z.Suggestion_TotalMonthMinutes;
            Number = z.Number;
            if (setting != null)
            {
                Current_TotalWeeklyMinutes = setting.Current_TotalWeeklyMinutes;
                Current_WateringDays = setting.Current_WateringDays;
                //Current_RunTimeDaily = setting.Current_RunTimeDaily;
                ScheduleType = (ScheduleTypes)setting.ScheduleTypeID;
                MaxCycleTime = setting.MaxCycleTime;
                MaxSoakTime = setting.MaxSoakTime;
            }
            IsAccepted = z.IsAccepted;

        }

      
    }
}
