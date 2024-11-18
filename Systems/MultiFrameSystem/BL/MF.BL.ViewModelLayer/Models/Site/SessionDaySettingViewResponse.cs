using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SessionDaySettingViewResponse
    {
        public long SessionID { get; set; }

        public string SessionName { get; set; }
        public SessionDaySettingView[] ListDays { set; get; }
        public SessionDaySettingViewResponse()
        {

        }
    }
}
