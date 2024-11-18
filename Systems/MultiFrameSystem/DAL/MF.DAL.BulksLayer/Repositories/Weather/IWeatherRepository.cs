using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Weather
{
    public interface IWeatherForecastsRepository : IDisposable
    {
        //Weekly
        bool AddWeeklyForecast<T>(Models.ForecastDataLog<T[]> weeklyForecasts);
        Models.ForecastDataLog<T[]> GetWeeklyForecast<T>(DateTime datetime, Models.Location location);
        Models.ForecastDataLog<T[]>[] GetWeeklyForecasts<T>(DateTime datetime, Models.Location location, int RecordsLimit = 5);

        //Daily
        bool AddDailyForecast<T>(Models.ForecastDataLog<T> dailyForecast);
        Models.ForecastDataLog<T> GetDailyForecast<T>(DateTime datetime, Models.Location location);
        Models.ForecastDataLog<T>[] GetDailyForecasts<T>(DateTime datetime, Models.Location location, int RecordsLimit = 5);
    }
}
