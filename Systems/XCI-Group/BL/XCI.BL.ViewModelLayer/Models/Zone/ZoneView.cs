
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;


namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
   public  class ZoneView
    {
        public string SN { get; set; }
        public int ZoneNumber { get; set; }
        public string Name { get; set; }

        public string ImageURI { get; set; }

        public ZoneListView [] DeviceZones { set; get; }
        public ZoneIrrigationSettingsView Settings { get; set; }
        public ZoneFlowSensorSettingsView FlowSensorSettings { get; set; }

        public Schedule.BaseZoneScheduleView ScheduleView { get; set; }
       // public ZoneIrrigationSuggestionView IrrigationSuggestions { get; set; }
        public AdvisorAllOptionsView CategoriesView { get; set; }
    }
}
