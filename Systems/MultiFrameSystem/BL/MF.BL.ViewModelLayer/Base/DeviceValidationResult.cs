using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Base
{
    public class DeviceValidationResult
    {
        public bool IsValid { get; set; }
        public long DeviceID
        {
            get
            {
                return AttachedDevice != null ? AttachedDevice.DeviceID : DetachedDevice.DeviceID;
            }
        }

        public bool IsDetachedDevice { get; set; }
        public DAL.AdminLayer.Models.DeviceInfoWithParent AttachedDevice { get; set; }
        public DAL.AdminLayer.Models.MainDevice DetachedDevice { get; set; }

    }
}
