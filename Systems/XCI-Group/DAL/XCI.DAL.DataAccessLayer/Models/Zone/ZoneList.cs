using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone
{
    public class ZoneList
    {
        //details
        public string Name { get; set; }
        public int Number { get; set; }

        public string ImageURI { get; set; }

        //settings
        public bool IsEnabled { get; set; }
    }
}
