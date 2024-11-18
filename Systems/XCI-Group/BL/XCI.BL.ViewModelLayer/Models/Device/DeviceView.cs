using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device
{
    public class DeviceView
    {
        //details + security
        public string Name { get; set; }
        public string SN { get; set; }
        public int ModelID { get; set; }


        public int TotalActivatedZones { get; set; }
        public int MaxZones { get; set; }
        public string FirmwareVersion { get; set; }

        //settings

        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }

        public DateTime CreationDate { get; set; }

        public DeviceView(DAL.DataAccessLayer.Models.Device.DeviceBase device)
        {
            if (device == null)
                return;

            Name = device.Name;
            SN = device.SN;
            CreationDate = device.CreationDate;
            ModelID = device.ModelID;

            TotalActivatedZones = device.ActivatedZones;
            MaxZones = device.MaxZones;
            FirmwareVersion = device.Firmware;

            Latitude = string.IsNullOrEmpty(device.Map_Latitude) ? 0 : decimal.Parse(device.Map_Latitude);
            Longitude = string.IsNullOrEmpty(device.Map_Longitude) ? 0 : decimal.Parse(device.Map_Longitude);
        }

        public DeviceView()
        {

        }

    }

}
