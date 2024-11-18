using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class AdvisorUpdateAllOptionsView
    {
        public string SN { get; set; }
        public int? ZoneNumber { get; set; }

        public AdvisorUpdateSelectedTypeView[] Types { get; set; } 
    }
}
