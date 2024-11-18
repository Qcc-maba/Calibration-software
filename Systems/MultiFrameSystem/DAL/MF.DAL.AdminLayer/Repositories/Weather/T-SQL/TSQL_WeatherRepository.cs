using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Weather.TSQL
{
    public class TSQLIWeatherRepository : BaseConnector, IWeatherRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "MFSystemAdminDB";

        #endregion

        #region ctor(s)

        private void initCtor()
        {
        }

        public TSQLIWeatherRepository()
            : base(DEFAULT_STRING_CONNECTION)
        {
            initCtor();
        }

        public TSQLIWeatherRepository(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {
            initCtor();
        }

        public TSQLIWeatherRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
            initCtor();
        }

        #endregion

        #region IWeatherRepository members

        public BaseWeatherAlgorithm WeatherAlgorithm_Get(long SiteID)
        {
            return Connector.GetEntity<BaseWeatherAlgorithm>(this.Connector.CreateProcedureEnumerator("[Site].[WeatherAlgorithm_Get]",
                                                                  new IDataParameter[]
                                                                  {
                                                                      Connector.CreateParameter("SiteID",SiteID)
                                                                  }));
        }

        public bool WeatherAlgorithm_UpdateSite(bool AsDefaultValuesOnly, long UserID, long SiteID, long AlgorithmID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("[Site].[WeatherAlgorithm_Update]",
                                                          new IDataParameter[]
                                                          {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("UserID",UserID),
                                                                        Connector.CreateParameter("AsDefaultValuesOnly",AsDefaultValuesOnly),
                                                                        Connector.CreateParameter("DefaultAlgorithmID",AlgorithmID),
                                                          },
                                                          out rowsAffected,
                                                          out Result);

            return Result;
        }

        public BaseWeatherAlgorithm WeatherAlgorithm_Get(string SN)
        {
            return Connector.GetEntity<BaseWeatherAlgorithm>(this.Connector.CreateProcedureEnumerator("[Device].[WeatherAlgorithm_Get]",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        public bool WeatherAlgorithm_Update(string SN, long AlgorithmID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("[Device].[WeatherAlgorithm_Update]",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("AlgorithmID",AlgorithmID)},
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public WeatherAlgorithm_P1 WeatherAlgorithm_P1_Get(long AlgorithmID)
        {
            return Connector.GetEntity<WeatherAlgorithm_P1>(this.Connector.CreateProcedureEnumerator("[Weather].[Algorithm_P1_Get]",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("AlgorithmID",AlgorithmID),
                                                                    }));
        }

        public bool WeatherAlgorithm_P1_Update(WeatherAlgorithm_P1 algorithm)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("[Weather].[Algorithm_P1_Update]",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("AlgorithmID",algorithm.AlgorithmID),
                                                                        Connector.CreateParameter("IsEnabled",algorithm.IsEnabled),
                                                                        Connector.CreateParameter("ManualValues",algorithm.ManualValues),
                                                                        Connector.CreateParameter("HottestMonthTemp",algorithm.HottestMonthTemp),
                                                                        Connector.CreateParameter("TemperatureUnit",algorithm.TemperatureUnit),
                                                                        Connector.CreateParameter("NormalHumidity",algorithm.NormalHumidity),
                                                                        Connector.CreateParameter("PreciptationTreshold",algorithm.PreciptationTreshold),
                                                                        Connector.CreateParameter("ChangeHumidity_Per5Precent",algorithm.ChangeHumidity_Per5Precent),
                                                                        Connector.CreateParameter("ChangeTemp_Per5Deg",algorithm.ChangeTemp_Per5Deg)},
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public bool WeatherAlgorithm_P1_Add(WeatherAlgorithm_P1 algorithm)
        {
            var Result = false;
            int rowsAffected = 0;
            var algorithmID = Connector.GetProcedureResultInt64("[Weather].[Algorithm_P1_Add]",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("IsEnabled",algorithm.IsEnabled),
                                                                        Connector.CreateParameter("ManualValues",algorithm.ManualValues),
                                                                        Connector.CreateParameter("AlgorithmTypeID",algorithm.AlgorithmTypeID),
                                                                        Connector.CreateParameter("HottestMonthTemp",algorithm.HottestMonthTemp),
                                                                        Connector.CreateParameter("TemperatureUnit",algorithm.TemperatureUnit),
                                                                        Connector.CreateParameter("NormalHumidity",algorithm.NormalHumidity),
                                                                        Connector.CreateParameter("PreciptationTreshold",algorithm.PreciptationTreshold),
                                                                        Connector.CreateParameter("ChangeHumidity_Per5Precent",algorithm.ChangeHumidity_Per5Precent),
                                                                        Connector.CreateParameter("ChangeTemp_Per5Deg",algorithm.ChangeTemp_Per5Deg)},
                                                                        out rowsAffected,
                                                                        out Result);

            if (Result && algorithmID >= 0)
            {
                algorithm.AlgorithmID = algorithmID;
            }

            return Result;
        }

        public bool WeatherAlgorithm_P1_Delete(long AlgorithmID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("[Weather].[Algorithm_P1_Delete]",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("AlgorithmID",AlgorithmID)
                                                          },
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion
    }
}
