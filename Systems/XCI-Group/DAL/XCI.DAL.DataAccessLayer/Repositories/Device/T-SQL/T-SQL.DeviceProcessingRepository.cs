using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Device.TSQL
{
    public class TSQLDeviceProcessingRepository : BaseConnector, IDeviceProcessingRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "XCI-Group_AdminDB";

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

        public Models.Device.DeviceInfo GetDeviceInfo(string SN)
        {

            var DeviceInfo = Connector.GetEntity<Models.Device.DeviceInfo>(this.Connector.CreateProcedureEnumerator("HHS.GetDeviceInfo",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN)}));
            DeviceInfo.SN = SN;
            return DeviceInfo;
        }

        public Models.Device.DeviceInfo GetDeviceWithAccmulators(string SN)
        {
            Models.Device.DeviceInfo info = GetDeviceInfo(SN);
            if (info == null)
                return null;

            info.Accumulators = Connector.GetEntities<Models.Device.DeviceAccumulator>(this.Connector.CreateProcedureEnumerator("HHS.GetTimerPoints",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("@DeviceID",info.DeviceID)})).ToArray();

            info.SN = SN;

            return info;
        }

        public Models.Device.DeviceAccumulator[] GetDeviceAccumulators(long DeviceID)
        {
            var accumulators = Connector.GetEntities<Models.Device.DeviceAccumulator>(this.Connector.CreateProcedureEnumerator("HHS.GetTimerPoints",
                                                                                        new IDataParameter[] { Connector.CreateParameter("@DeviceID", DeviceID) }))
                                                                                    .ToArray();
            return accumulators;
        }

        public bool UpdateTimer_StartPoint(long DeviceID, Models.Device.DeviceAccumulator Accumulator)
        {
            bool result = false;
            int row = 0;

            var pointID_OutputParameter = Accumulator.ID == -1 ? Connector.CreateNullParameter("PointID", typeof(long)) :
                                                Connector.CreateParameter("PointID", Accumulator.ID);
            pointID_OutputParameter.Direction = ParameterDirection.InputOutput;

            Connector.GetProcedureResultInt32("HHS.UpdateTimer_StartPoint", new IDataParameter[] {
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("AccType",Accumulator.AccType),
                                                                        pointID_OutputParameter,

                                                                        Connector.CreateParameter("StartTicks",Accumulator.StartTicks),
                                                                        Connector.CreateParameter("StartDateTime",Accumulator.StartDateTimeView),
                                                                        Connector.CreateParameter("Start_Value",Accumulator.Start_Value),
                                                                    },
                                                                    out row,
                                                                    out result);

            if (result)
            {
                long _id = (long)pointID_OutputParameter.Value;
                if (Accumulator.ID != _id)
                {
                    Accumulator.ID = _id;
                }
            }

            return result;
        }

        public bool UpdateTimer_EndPoint(long DeviceID, Models.Device.DeviceAccumulator Accumulator)
        {
            bool result = false;
            int row = 0;

            var pointID_OutputParameter = Accumulator.ID == -1 ? Connector.CreateNullParameter("PointID", typeof(long)) :
                                                Connector.CreateParameter("PointID", Accumulator.ID);
            pointID_OutputParameter.Direction = ParameterDirection.InputOutput;

            Connector.GetProcedureResultInt32("HHS.UpdateTimer_EndPoint", new IDataParameter[] {
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("AccType",Accumulator.AccType),
                                                                        pointID_OutputParameter,

                                                                        Connector.CreateParameter("EndTicks",Accumulator.EndTicks),
                                                                        Connector.CreateParameter("EndDateTime",Accumulator.EndDateTimeView),
                                                                        Connector.CreateParameter("End_Value",Accumulator.End_Value),
                                                                    },
                                                                    out row,
                                                                    out result);

            if (result)
            {
                long _id = (long)pointID_OutputParameter.Value;
                if (Accumulator.ID != _id)
                {
                    Accumulator.ID = _id;
                }
            }

            return result;
        }

        public bool DeleteAccumulator(long DeviceID, long TimerID)
        {
            bool result = false;
            int row = 0;
            Connector.GetProcedureResultInt32("HHS.DeleteTimerPoint", new IDataParameter[] {
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("TimerID",TimerID)
                                                                    }, out row
                                                                    , out result);

            return result;
        }

        public bool DeleteAllAccumulators(long DeviceID)
        {
            bool result = false;
            int row = 0;
            Connector.GetProcedureResultInt32("HHS.DeleteAllTimerPoints", new IDataParameter[] {
                                                                        Connector.CreateParameter("DeviceID",DeviceID)
                                                                    }, out row
                                                                    , out result);

            return result;
        }

        public bool IsAlertActiveItem(long DeviceID, long Code, DateTime utc_now)
        {
            bool result = false;
            int row = 0;
            var result_out = Connector.GetProcedureResultInt32("HHS.IsAlertActiveItem",
                                                                      new IDataParameter[] {
                                                                       Connector.CreateParameter("Code",Code),
                                                                       Connector.CreateParameter("DeviceID",DeviceID),
                                                                        Connector.CreateParameter("LastDate",utc_now)
                                                                    }, out row
                                                                     , out result);

            return result_out == 1;
        }

        #endregion
    }
}
