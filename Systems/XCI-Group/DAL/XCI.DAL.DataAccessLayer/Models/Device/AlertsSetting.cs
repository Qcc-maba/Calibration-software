using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device
{
    public class AlertsSetting
    {
        public int AlertCode { get; set; }
        public string SN { get; set; }
        public string Name { get; set; }

        public bool? IsEnable { get; set; }
        public bool? SendSMS { get; set; }
        public bool? SendEmail { get; set; }
        public bool? Visible { get; set; }

        public bool Default_SendSMS { get; set; }
        public bool Default_SendEmail { get; set; }
        public bool Default_Visible { get; set; }
        public bool Default_IsActive { get; set; }

    }
}
