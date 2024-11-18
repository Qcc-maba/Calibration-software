using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone
{
    public  class ZoneIrrigationSuggestion
    {
        public DateTime? LastSuggestionAcceptedDate { get; set; }
        public bool IsAccepted { get; set; }

        public DateTime? LastSuggestionDate { get; set; }
        public int Suggestion_TotalWeeklyMinutes { get; set; }
        public int Suggestion_TotalWeeklyDays { get; set; }
        public int Suggestion_MaximumCycleMinutes { get; set; }
        public int Suggestion_SoakTimeMinutes { get; set; }
        public int Number { get; set; }
        public int Suggestion_RunTimeDaily { get; set; }

        public int Suggestion_TotalMonthMinutes { get; set; }

       


    }
}
