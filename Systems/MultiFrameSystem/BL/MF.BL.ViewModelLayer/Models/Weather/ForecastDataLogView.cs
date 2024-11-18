using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather
{
    public class ForecastDataLogView
    {
        public ForecastDataView[] ForecastsData { get; set; }
        public LocationView Location { set; get; }
        public DateTime RecordDate { get; set; }
        public bool Cached { get; set; }

        public ForecastDataLogView()
        {

        }
        public ForecastDataLogView(DAL.BulksLayer.Repositories.Weather.Models.ForecastDataLog<ForecastDataView[]> u)
        {
            this.Location = new LocationView() { lat = u.Location.lat, lon = u.Location.lon };
            this.RecordDate = u.RecordDate;
            ForecastsData = u.ForecastData;
        }


        public ForecastDataLogView(DAL.BulksLayer.Repositories.Weather.Models.ForecastDataLog<ForecastDataView> u)
        {
            this.Location = new LocationView() { lat = u.Location.lat, lon = u.Location.lon };
            this.RecordDate = u.RecordDate;
            ForecastsData = new ForecastDataView[] { u.ForecastData };
        }
    }
}
