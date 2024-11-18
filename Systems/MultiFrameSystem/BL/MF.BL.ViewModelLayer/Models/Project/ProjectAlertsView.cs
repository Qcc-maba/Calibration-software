using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{

    public class ProjectAlertsView
    {
        public long ProjectID { get; set; }
        public string ProjectName { get; set; }
        public DeviceAlertInSiteView[] DeviceAlertsView { set; get; }
        public long TotalItems { get; internal set; }
    }
}
