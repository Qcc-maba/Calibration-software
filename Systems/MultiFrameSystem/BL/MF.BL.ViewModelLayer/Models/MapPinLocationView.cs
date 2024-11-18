using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models
{
    public class MapPinLocationView
    {
        //###.#######(10 digits)
        public decimal Latitude { get; set; }
        //###.#######(10 digits)
        public decimal Longitude { get; set; }

        public MapPinLocationView()
        {

        }

        public MapPinLocationView(string lat, string lon)
        {
            Latitude = string.IsNullOrEmpty(lat) ? 0 : decimal.Parse(lat);
            Longitude = string.IsNullOrEmpty(lon) ? 0 : decimal.Parse(lon);
        }
    }
}
