using System;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather.Models
{
    public class Location
    {
        public decimal lat { get; set; }
        public decimal lon { get; set; }


        public override int GetHashCode()
        {
            return base.GetHashCode();
        }
        public override string ToString()
        {
            return $"Location::{lat}.{lon}";
        }
        public override bool Equals(object obj)
        {
            var o = obj as Location;
            return o != null && o.lat == this.lat && o.lon == this.lon;
        }
    }
}
