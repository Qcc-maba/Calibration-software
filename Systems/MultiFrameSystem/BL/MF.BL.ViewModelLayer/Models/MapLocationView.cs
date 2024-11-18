using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models
{
    public class MapLocationView
    {
        public MapPinLocationView MapCenter { get; set; }
        public int ZoomLevel { get; set; }
        public string Mode { get; set; }
        public bool AutoBounds { get; set; }

        public MapLocationView()
        {
            AutoBounds = true;
            ZoomLevel = 12;
        }

        public MapLocationView(DAL.AdminLayer.Models.MainSite site)
        {
            this.MapCenter = new MapPinLocationView(site.MapCenter_Latitude, site.MapCenter_Longitude);
            this.Mode = site.MapCenter_Mode;
            this.AutoBounds = site.MapCenter_AutoBounds;
            this.ZoomLevel = site.MapCenter_Zoom.GetValueOrDefault(0);
        }

        public MapLocationView(DAL.AdminLayer.Models.MapLocationData location)
        {
            this.MapCenter = new MapPinLocationView()
           {
               Latitude = string.IsNullOrEmpty(location.MapCenter_Latitude) ? 0 : decimal.Parse(location.MapCenter_Latitude),
               Longitude = string.IsNullOrEmpty(location.MapCenter_Longitude) ? 0 : decimal.Parse(location.MapCenter_Longitude)

           };
            AutoBounds = location.MapCenter_AutoBounds;
            this.Mode = location.MapCenter_Mode;
            this.ZoomLevel = (int)location.MapCenter_Zoom;
        }

        //internal void CopyTo(DAL.AdminLayer.Models.MainSite newSite)
        //{
        //    this.MapCenter=new MapPinLocationView()
        //    {
        //         Latitude=newSite.MapCenter_Latitude
        //    }

        //}
        internal void CopyToSite(DAL.AdminLayer.Models.MainSite site)
        {
            site.MapCenter_Latitude = this.MapCenter.Latitude.ToString();
            site.MapCenter_Longitude = this.MapCenter.Longitude.ToString();

            site.MapCenter_Mode = this.Mode;
            site.MapCenter_AutoBounds = this.AutoBounds;
            site.MapCenter_Zoom = (byte)this.ZoomLevel;
        }
        internal void CopyToLocationDAL(DAL.AdminLayer.Models.MapLocationData location)
        {
            location.MapCenter_Latitude = this.MapCenter.Latitude.ToString();
            location.MapCenter_Longitude = this.MapCenter.Longitude.ToString();

            location.MapCenter_Mode = this.Mode;
            location.MapCenter_AutoBounds = this.AutoBounds;
            location.MapCenter_Zoom = (byte)this.ZoomLevel;
        }
    }
}
