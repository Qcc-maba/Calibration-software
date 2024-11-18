using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.ElasticsearchLibrary;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.ES
{
    public class WeatherESSettings : ElasticSettings
    {
        public string Index_WeeklyIndex_Name { get; set; } = "forecasts_weekly_dwh";
        public string Index_DailyIndex_Name { get; set; } = "forecasts_daily_dwh";

        public decimal DistanceKM { get; set; } = 2;

        public WeatherESSettings() : base()
        {
        }

    }
}
