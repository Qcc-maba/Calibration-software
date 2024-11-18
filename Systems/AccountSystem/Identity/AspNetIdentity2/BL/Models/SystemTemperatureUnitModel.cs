using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class SystemTemperatureUnitModel
    {
        public int TypeUnitID { get; set; }
        public string DisplayName { get; set; }
        public string DisplayUnit { get; set; }
        public bool IsDefault { get; set; }

        public SystemTemperatureUnitModel()
        {

        }

        public SystemTemperatureUnitModel(DAL.SystemTemperatureUnit unit)
        {
            TypeUnitID = unit.TypeUnitID;
            DisplayUnit = unit.DisplayUnit;
            IsDefault = unit.IsDefault;
            DisplayName = unit.DisplayName;
        }
    }
}