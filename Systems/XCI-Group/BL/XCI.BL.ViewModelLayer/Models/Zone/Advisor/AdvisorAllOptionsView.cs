using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{

    public enum AdvisorTypes : int
    {
        PlantType = 0,
        SprinklerType = 1,
        SlopeType = 2,
        SoilType = 3,
        SunExposureType = 4
    }

    public class AdvisorAllOptionsView
    {
        public string SN { get; set; }
        public int? ZoneNumber { get; set; }

        public ZoneIrrigationSuggestionView IrrigationSuggestion { set; get; }
        public AdvisorTypeView<AdvisorPlantOptionalTypeView> PlantType { get; set; }
        public AdvisorTypeView<BaseAdvisorOptionalTypeView> SlopeType { get; set; }
        public AdvisorTypeView<AdvisorSprinklerOptionalTypeView> SprinklerType { get; set; }
        public AdvisorTypeView<BaseAdvisorOptionalTypeView> SoilType { get; set; }
        public AdvisorTypeView<AdvisorSunExposureOptionalTypeView> SunExposureType { get; set; }
    }
}
