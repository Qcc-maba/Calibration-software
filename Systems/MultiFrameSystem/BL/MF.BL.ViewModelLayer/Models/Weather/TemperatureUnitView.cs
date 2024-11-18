namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather
{
    public class ThreeUnitsView
    {
        public enum TemperatureUnits
        {
            Celsius,
            Fahrenheit
        };

        public ThreeUnitsView()
        {
        }

        public decimal? Avg { get; set; }
        public decimal? High { get; set; }
        public decimal? Low { get; set; }
        public string UnitLabel { get; set; }
        public string ValueType { get; set; }

    }
}