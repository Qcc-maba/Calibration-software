using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public  class BaseAdvisorOptionalTypeView
    {
        public bool IsSelected { get; set; }

        public bool IsCustom { get; set; }

        public int TypeID { get; set; }
        public string TypeTitle { get; set; }

        public decimal? Value { get; set; }

        public string ImageURI { get; set; }

        public bool IsDefault { set; get; }

      
    }
}
