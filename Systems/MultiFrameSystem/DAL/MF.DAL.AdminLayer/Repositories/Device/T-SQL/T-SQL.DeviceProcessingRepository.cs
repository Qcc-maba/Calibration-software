using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Device.TSQL
{
    public class TSQLDeviceProcessingRepository : BaseConnector, IDeviceProcessingRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "MFSystemAdminDB";

        #endregion

        #region ctor(s)

        private void initCtor()
        {
            this.ThrowExceptions = true;
        }

        public TSQLDeviceProcessingRepository()
            : base(DEFAULT_STRING_CONNECTION)
        {
            initCtor();
        }

        public TSQLDeviceProcessingRepository(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {
            initCtor();
        }

        public TSQLDeviceProcessingRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
            initCtor();
        }

        #endregion

        #region IDeviceProcessingRepository Implementation

        public Models.DeviceInfo GetDeviceInfo(string SN)
        {

            var DeviceInfo = Connector.GetEntity<Models.DeviceInfo>(this.Connector.CreateProcedureEnumerator("HHS.GetDeviceInfo",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN)}));
            DeviceInfo.SN = SN;
            return DeviceInfo;
        }

        public Models.DeviceAccumulator[] GetDeviceAccumulators(long DeviceID)
        {
            return Connector.GetEntities<Models.DeviceAccumulator>(this.Connector.CreateProcedureEnumerator("HHS.GetTimerPoints",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("@DeviceID",DeviceID)}))
                                                                   .ToArray();

        }

        public bool AddAccumulator(long DeviceID, Models.DeviceAccumulator Accumulator)
        {
            bool result = false;
            int row = 0;
            Connector.GetProcedureResultInt32("HHS.AddTimerPoint", new IDataParameter[] {
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("TimerDate",Accumulator.EndPoint),
                                                                        Connector.CreateParameter("Timer",Accumulator.EndTicks),
                                                                        Connector.CreateParameter("Type",Accumulator.AccType)
                                                                    },
                                                                    out row,
                                                                    out result);

            return result;
        }

        public bool UpdateAccumulator(Models.DeviceAccumulator Accumulator)
        {

            bool result = false;
            int row = 0;
            Connector.GetProcedureResultInt32("HHS.UpdateTimerPoint", new IDataParameter[] {
                                                                        Connector.CreateParameter("ID",Accumulator.ID),
                                                                        Connector.CreateParameter("TimerDate",Accumulator.EndPoint),
                                                                        Connector.CreateParameter("Timer",Accumulator.EndTicks)
                                                                    }, out row
                                                                    , out result);

            return result;
        }

        public bool DeleteAccumulator(long DeviceID)
        {
            bool result = false;
            int row = 0;
            Connector.GetProcedureResultInt32("HHS.DeleteTimerPoint", new IDataParameter[] {
                                                                        Connector.CreateParameter("DeviceID",DeviceID)
                                                                    }, out row
                                                                    , out result);

            return result;
        }

        public bool UpdateAccumulator(string SN, string AccType, DateTime date)
        {
            bool result = false;
            int row = 0;
            Connector.GetProcedureResultInt32("HHS.UpdateTimerPoint_SN", new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("AccType",AccType),
                                                                        Connector.CreateParameter("Timer",date.Ticks),
                                                                        Connector.CreateParameter("TimerDate",date)
                                                                    }, out row
                                                                    , out result);

            return result;
        }

        public IEnumerable<Models.UserInfo> GetUserToSendEmail(long SiteID, long DeviceID, long Code)
        {
            return Connector.GetEntities<Models.UserInfo>(Connector.CreateProcedureEnumerator("HHS.GetUserSubscribe",
                                                                     new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("Code",Code)
                                                                    }));
        }

        public bool UpadteAlertManagement(long SiteID, long DeviceID, long Code, DateTime LastDate, out int interval)
        {
            bool result = false;
            int row = 0;
            interval = Connector.GetProcedureResultInt32("HHS.UpadteAlertManagement",
                                                                     new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("Code",Code),
                                                                         Connector.CreateParameter("LastDate",LastDate)
                                                                    }, out row
                                                                    , out result);

            return result;
        }

        public bool IsAlertActiveItem(long SiteID, long DeviceID, long Code, DateTime utc_now)
        {
            bool result = false;
            int row = 0;
            var result_out = Connector.GetProcedureResultInt32("HHS.IsAlertActiveItem",
                                                                      new IDataParameter[] {
                                                                       Connector.CreateParameter("Code",Code),
                                                                       Connector.CreateParameter("DeviceID",DeviceID),
                                                                       Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("LastDate",utc_now)
                                                                    }, out row
                                                                     , out result);

            return result_out == 1;
        }

        #endregion
    }
}
