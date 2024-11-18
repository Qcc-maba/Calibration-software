using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class DeviceTypeView
    {
        public int TypeID { get; set; }
        public string Name { get; set; }

        public DeviceTypeView()
        {

        }

        public DeviceTypeView(DAL.AdminLayer.Models.DeviceType type)
        {
            TypeID = type.TypeID;
            Name = type.Name;
        }

    }
}
