using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class DeviceView
    {
        #region properties
        public string Name { get; set; }
        public string SN { get; set; }
        public long DeviceID { get; set; }
        public DeviceTypeView DeviceType { get; set; }
        public MapPinLocationView Location { get; set; }

        #region can be changed by other system

        public int TimeZoneID { get; set; }
        public int TimeZoneOffset { get; set; }

        public bool IsAlertsEnabled { get; set; }
        public string FirmwareVersion { get; set; }
        public int? TotalActivatedZones { get; set; }
        public int MaxZones { get; set; }

        public DateTime? HoldUntil { get; set; }
        public DeviceStatusView Status { get; set; }

        #endregion

        #endregion


        public DeviceView()
        {

        }

        public DeviceView(DAL.AdminLayer.Models.MainDevice device)
        {
            Name = device.Name;
            SN = device.SN;
            DeviceID = device.DeviceID;

            DeviceType = new DeviceTypeView()
            {
                Name = device.DeviceTypeName,
                TypeID = device.DeviceTypeID
            };

            Location = new MapPinLocationView()
            {
                Latitude = string.IsNullOrEmpty(device.Map_Latitude) ? 0 : decimal.Parse(device.Map_Latitude),
                Longitude = string.IsNullOrEmpty(device.Map_Longitude) ? 0 : decimal.Parse(device.Map_Longitude)
            };            

            this.TimeZoneID = device.TimeZoneID;
            this.TimeZoneOffset = DAL.AdminLayer.Models.GlobalizationZone.CalculateActualOffset(device.TimeSystemZoneID);

            IsAlertsEnabled = device.IsAlertsEnabled;

            FirmwareVersion = device.FirmwareVersion;
            TotalActivatedZones = device.TotalActivatedZones;
            MaxZones = device.MaxZones;

            this.HoldUntil = device.HoldUntilDate;


            Status = new DeviceStatusView()
            {
                StatusID = device.StatusID,
                Name = device.StatusName
            };
        }

    }
}
