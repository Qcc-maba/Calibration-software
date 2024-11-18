using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public partial class MainSite
    {
        public string Name { get; set; }
        public long SiteID { get; set; }
        public long? ParentSiteID { get; set; }
        public System.DateTime CreateDate { get; set; }
        public System.DateTime UpdateDate { get; set; }
        public string MapCenter_Latitude { get; set; }
        public string MapCenter_Longitude { get; set; }
        public byte? MapCenter_Zoom { get; set; }
        public string MapCenter_Mode { get; set; }
        public bool MapCenter_AutoBounds { get; set; }
        public long? WeatherAlgorithmID { get; set; }

    }
}
