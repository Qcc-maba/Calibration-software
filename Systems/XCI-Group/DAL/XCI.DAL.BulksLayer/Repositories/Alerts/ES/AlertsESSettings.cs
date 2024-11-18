using Maba.Connectors.ElasticsearchLibrary;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Alerts.ES
{
    public class AlertsESSettings : ElasticSettings
    {
        public string Index_Main_Name { get; set; }

        public string Index_Temp_Name { get; set; }

        public AlertsESSettings() : base()
        {
            this.Index_Main_Name = "logs_dwh";
            this.Index_Temp_Name = "logs_tempdb";
        }
    }
}
