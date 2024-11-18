using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Weather
{
    public interface IWeatherRepository : IDisposable
    {
        //site
        BaseWeatherAlgorithm WeatherAlgorithm_Get(long SiteID);
        bool WeatherAlgorithm_UpdateSite(bool AsDefaultValuesOnly, long UserID, long SiteID, long AlgorithmID);

        //device
        BaseWeatherAlgorithm WeatherAlgorithm_Get(string SN);
        bool WeatherAlgorithm_Update(string SN, long AlgorithmID);


        //----------------Typed Algorithms ----------------------------
        WeatherAlgorithm_P1 WeatherAlgorithm_P1_Get(long AlgorithmID);

        bool WeatherAlgorithm_P1_Add(WeatherAlgorithm_P1 algorithm);

        bool WeatherAlgorithm_P1_Update(WeatherAlgorithm_P1 algorithm);
        bool WeatherAlgorithm_P1_Delete(long AlgorithmID);
    }
}
