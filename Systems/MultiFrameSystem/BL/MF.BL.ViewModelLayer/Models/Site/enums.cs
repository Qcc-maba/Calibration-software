using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public enum SharingVerificationStatus
    {
        Pending = 1,
        Rejected = 2,
        Accepted = 3,
        NoSuchUser = 4,
        Failed2Share = 5,
        Failed2UpdateShare = 6
    }
}
