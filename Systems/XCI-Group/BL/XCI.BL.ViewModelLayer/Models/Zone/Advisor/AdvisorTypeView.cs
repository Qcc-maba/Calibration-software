using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class AdvisorTypeView<T>
    {
        public int AdvisorTypeID { get; set; }
        public string TypeTitle { get; set; }
        //@@@@
        public decimal MinValue { get; set; }
        public decimal MaxValue { get; set; }

        public T[] OptionalValues { get; set; }
    }
}
