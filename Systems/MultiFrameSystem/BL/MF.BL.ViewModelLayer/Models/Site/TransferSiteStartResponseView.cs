using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class TransferSiteStartResponseView : TransferSiteView
    {
        public bool IsCompleted { get; set; }
        public bool Result { get; set; }

        public TransferSiteStartResponseView()
        {

        }
    }
}
