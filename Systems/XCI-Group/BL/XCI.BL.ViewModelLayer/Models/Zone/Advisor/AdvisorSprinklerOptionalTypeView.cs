using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public  class AdvisorSprinklerOptionalTypeView  : BaseAdvisorOptionalTypeView
    {
        public decimal? PrecipRate { get; set; }
        public decimal? RuntimeMultiplier { get; set; }
        public decimal? FlowEstimate { get; set; }
    }
}
