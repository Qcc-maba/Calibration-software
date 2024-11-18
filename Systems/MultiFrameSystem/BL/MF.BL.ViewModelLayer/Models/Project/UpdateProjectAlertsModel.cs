using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class UpdateProjectAlertsModel
    {
        public long ProjectID { get; set; }
        public UpdateDeviceAlertModel[] DeviceAlertsView { set; get; }

    }
}
