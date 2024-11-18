using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class SystemTypesModel
    {
        public SystemTimeZoneModel[] TimeZones { get; set; }

        public SystemUIFormatModel[] UIFormats { get; set; }

        public SystemTemperatureUnitModel[] TemperatureUnits { get; set; }

        public SystemTypesModel()
        {

        }
    }
}