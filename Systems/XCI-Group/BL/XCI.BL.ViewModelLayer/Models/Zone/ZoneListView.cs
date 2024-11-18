using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class ZoneListView
    {
        //details
        public string Name { get; set; }
        public int ZoneNumber { get; set; }

        public string ImageURI { get; set; }

        //settings
        public bool IsEnabled { get; set; }

        public ZoneListView(DAL.DataAccessLayer.Models.Zone.ZoneList u)
        {
            if (u == null)
                return;
            Name = u.Name;
            ZoneNumber = u.Number;
            ImageURI = u.ImageURI;
            IsEnabled = u.IsEnabled;
        }
    }
}
