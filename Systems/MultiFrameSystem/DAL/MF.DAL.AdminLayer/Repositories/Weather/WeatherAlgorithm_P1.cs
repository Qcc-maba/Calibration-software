using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Weather
{
    public class WeatherAlgorithm_P1
    {
        #region CONSTANST

        public const int ALGORITHM_TYPE_ID = 10;

        #endregion

        public int AlgorithmTypeID { get { return ALGORITHM_TYPE_ID; } }

        public long AlgorithmID { get; set; }

        public bool IsEnabled { get; set; }
        public bool ManualValues { get; set; }

        public decimal HottestMonthTemp { get; set; }
        public string TemperatureUnit { get; set; }

        public int NormalHumidity { get; set; }
        /// <summary>
        /// Threshold for counting a day as rainy.
        /// </summary>
        public short PreciptationTreshold { get; set; }
        public short ChangeTemp_Per5Deg { get; set; }
        public short ChangeHumidity_Per5Precent { get; set; }


        public WeatherAlgorithm_P1()
        {
            AlgorithmID = -1;
        }

    }
}
