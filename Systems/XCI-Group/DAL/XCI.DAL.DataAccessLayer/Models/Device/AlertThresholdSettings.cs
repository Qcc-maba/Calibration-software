using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class AlertThresholdSettings
    {
        public decimal? OverCurrentThreshold { get; set; }
        public decimal? UnderCurrentThreshold { get; set; }

        public bool IsAlertsEnabled { get; set; }

        public AlertThresholdSettings()
        {
                
        }
    }
}
