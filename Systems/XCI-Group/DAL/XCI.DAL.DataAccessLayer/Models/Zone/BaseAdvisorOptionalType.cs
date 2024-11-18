using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone
{
    public class BaseAdvisorOptionalType
    {
        public int ID { get; set; }
        public string TypeTitle { get; set; }
        public string Description { get; set; }
        public string ImageLink { get; set; }
        public bool IsDefault { set; get; }
        public bool IsCustom { get; set; }

    }
}
