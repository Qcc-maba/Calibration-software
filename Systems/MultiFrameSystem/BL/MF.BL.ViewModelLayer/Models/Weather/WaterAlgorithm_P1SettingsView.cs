using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Weather
{
    public class WaterAlgorithm_P1SettingsView : BaseWaterAlgorithmView
    {
        public const int TypeID = DAL.AdminLayer.Repositories.Weather.WeatherAlgorithm_P1.ALGORITHM_TYPE_ID;

        public bool IsEnabled { get; set; }
        public bool ManualValues { get; set; }

        //Cellius
        public decimal HottestMonthTemp { get; set; }
        public string TemperatureUnit { get; set; }
        public int NormalHumidity { get; set; }
        /// <summary>
        /// Treshold for counting a day as rainy.
        /// </summary>
        public short PreciptationTreshold { get; set; }

        public short ChangeTemp_Per5Deg { get; set; }
        public short ChangeHumidity_Per5Precent { get; set; }

        public WaterAlgorithm_P1SettingsView()
        {

        }

        public WaterAlgorithm_P1SettingsView(DAL.AdminLayer.Repositories.Weather.WeatherAlgorithm_P1 p1)
        {
            //internals
            this.AlgorithmID = p1.AlgorithmID;
            this.AlgorithmTypeID = p1.AlgorithmTypeID;

            //public
            this.IsEnabled = p1.IsEnabled;
            this.ManualValues = p1.ManualValues;
            this.HottestMonthTemp = p1.HottestMonthTemp;
            this.TemperatureUnit = p1.TemperatureUnit;
            this.NormalHumidity = p1.NormalHumidity;
            this.PreciptationTreshold = p1.PreciptationTreshold;
            this.ChangeTemp_Per5Deg = p1.ChangeTemp_Per5Deg;
            this.ChangeHumidity_Per5Precent = p1.ChangeHumidity_Per5Precent;
        }

        public DAL.AdminLayer.Repositories.Weather.WeatherAlgorithm_P1 To_DAL()
        {
            return new DAL.AdminLayer.Repositories.Weather.WeatherAlgorithm_P1()
            {
                IsEnabled = this.IsEnabled,
                TemperatureUnit = this.TemperatureUnit,
                ManualValues = this.ManualValues,
                AlgorithmID = this.AlgorithmID,
                ChangeHumidity_Per5Precent = this.ChangeHumidity_Per5Precent,
                ChangeTemp_Per5Deg = this.ChangeTemp_Per5Deg,
                HottestMonthTemp = this.HottestMonthTemp,
                NormalHumidity = this.NormalHumidity,
                PreciptationTreshold = this.PreciptationTreshold
            };
        }

        public void ConvertTempUnit(string temperaturUnit)
        {
            if (this.TemperatureUnit == temperaturUnit)
                return;

            switch (this.TemperatureUnit)
            {
                //convert F -> C
                case "F":
                    this.HottestMonthTemp = decimal.Round(((HottestMonthTemp - 32) / 1.8m), 2);
                    break;
                //convert C -> F
                case "C":
                    this.HottestMonthTemp = decimal.Round(((HottestMonthTemp * 1.8m) + 32), 2);
                    break;
                default:
                    this.TemperatureUnit = "C";
                    break;
            }

            this.TemperatureUnit = temperaturUnit;

        }
    }
}
