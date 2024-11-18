using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather
{
    public class PrecipitationObject
    {
        public decimal? Night { set; get; }
        public decimal? Day { set; get; }
        public decimal? Avg { set; get; }

        public string UnitLabel { set; get; }


        public string ValueType { get; set; }
    }
}
