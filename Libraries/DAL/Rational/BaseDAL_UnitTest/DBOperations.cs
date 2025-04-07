using Maba.DAL.BaseDAL;
using Maba.DAL.BaseDAL.Records;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Runtime.Remoting.Messaging;
using System.Text;
using System.Threading.Tasks;
using System.Xml;

namespace Maba.DAL.BaseDAL.UnitTest.Connectors
{
    public class DBOperations : BaseConnector
    {
        #region Ctor

        public DBOperations(string sectionName)
            : base(sectionName)
        {

        }

        #endregion

        #region Table

        public MyRecord[] TableStatement()
        {
            return Connector.GetEntities<MyRecord>(Connector.CreateTableEnumerator(CONSTANSTS.RECORDS_TABLES, new string[] { "RecordID_32" }))
                .ToArray();
        }

        #endregion

        #region Scalar - Function


        public int GetScalarFunction()
        {
            var Result = false;
            int dummyParameter = -1;
            return Connector.RunScalarFunctionResult<int>(CONSTANSTS.SCALAR_TABLEFUNCTION, -1, out Result, new IDataParameter[] { Connector.CreateParameter("RecordID_32", dummyParameter) });
        }


        #endregion

        #region Table-Function

        public async void fff()
        {

            //List<CorrectionValues> CV= new List<CorrectionValues>();
            ////bool results;
            //string TC = "21-449";

            //SqlParameter id = new SqlParameter("@ID", SqlDbType.NVarChar, 50);
            //{
            //    id.Direction = ParameterDirection.Input;
            //    id.Value = TC;
            //}
            //var t = await Connector.RunProcedureAsync("GetSensorByName", new IDataParameter[] { id });

            //while (t.Read())
            //{
            //    var row = new CorrectionValues();
            //    row.TemperatureValue = t.GetDouble(0);
            //    row.Deviation = t.GetDouble(1);
            //    CV.Add(row);
            //}

        }
        public async Task<List<CorrectionValues>> ffff()
        {

            List<CorrectionValues> CV = new List<CorrectionValues>();

            ////bool results;
            //string TC = "30-800";

            //SqlParameter id = new SqlParameter("@MabaID", SqlDbType.NVarChar, 50);
            //{
            //    id.Direction = ParameterDirection.Input;
            //    id.Value = TC;
            //}
            //var t = await Connector.RunProcedureAsync("GetSensorByName", new IDataParameter[] { id });

            //while (t.Read())
            //{
            //    var row = new CorrectionValues();
            //    row.TemperatureValue = t.GetDouble(0);
            //    row.HumidityValue = t.GetDouble(1);
            //    row.Deviation = t.GetDouble(2);
            //    CV.Add(row);
            //}
            return CV;
        }

        public IEnumerable<MyRecord> GetRecords_TableFunction(long ID_Min, long ID_Max, string[] orderByColumns)
        {
            return this.Connector.GetEntities<MyRecord>(
                Connector.CreateTableFunctionEnumerator(CONSTANSTS.SELECT_RECORDS_TABLEFUNCTION, orderByColumns,
                new IDataParameter[] { this.Connector.CreateParameter("ID_Min", ID_Min), this.Connector.CreateParameter("ID_Max", ID_Max), }));
        }

        #endregion

        #region Procedures

        public long ProcedureWithOutParameter(out bool result)
        {
            long result_int64 = -1;
            var p = Connector.CreateOutParameter("@RecordID_64", result_int64);
            Connector.WrapDataReader(Connector.RunProcedure(CONSTANSTS.GET_RESULTINT64_SP, new IDataParameter[] { p }, out result), null);
            result_int64 = (long)p.Value;
            return result_int64;
        }

        public long GetResultInt64(out bool result, out int rowsAffected)
        {
            long result_int64 = -1;
            var p = Connector.CreateOutParameter("@RecordID_64", result_int64);
            Connector.GetProcedureResultInt64(CONSTANSTS.GET_RESULTINT64_SP, new IDataParameter[] { p }, out rowsAffected, out result);
            result_int64 = (long)p.Value;
            return result_int64;
        }

        public int GetResultInt32(out bool result, out int rowsAffected)
        {
            int result_int32 = -1;

            var p = Connector.CreateOutParameter("@RecordID_32", result_int32);
            Connector.GetProcedureResultInt32(CONSTANSTS.GET_RESULTINT32_SP, new IDataParameter[] { p }, out rowsAffected, out result);

            result_int32 = (int)p.Value;

            return result_int32;
        }

        public bool AddRecords(MyRecord[] InitRecords)
        {
            bool Result = false;
            foreach (var r in InitRecords)
            {
                Connector.WrapDataReader(Connector.RunProcedure(CONSTANSTS.INSERT_RECORDS_SP,
                       new IDataParameter[] {
                           Connector.CreateParameter("@RecordID_64", r.RecordID_64),
                           Connector.CreateParameter("@RecordID_32", r.RecordID_32),
                            Connector.CreateParameter("@CreationDate", r.CreationDate),
                            Connector.CreateParameter("@IsEnabled", r.IsEnabled),
                            Connector.CreateParameter("@FirstName", r.FirstName),
                            Connector.CreateParameter("@LastName", r.LastName),
                            Connector.CreateParameter("@Data", r.Data),
                            Connector.CreateParameter("@Flow", r.Flow),
                            Connector.CreateParameter("@RecordID_Null", r.RecordID_Null),
                            Connector.CreateParameter("@StationNumber", r.StationNumber),
                             Connector.CreateParameter("@ProgramNumber", r.ProgramNumber),

                       },
                           out Result), null);

                if (!Result)
                    break;
            }

            return Result;
        }

        public IEnumerable<MyRecord> GetRecords_SP1(long ID_Min, long ID_Max)
        {
            return Connector.GetEntities<MyRecord>(
                Connector.CreateProcedureEnumerator(CONSTANSTS.SELECT_RECORDS_SP,
                new IDataParameter[] { Connector.CreateParameter("ID_Min", ID_Min), Connector.CreateParameter("ID_Max", ID_Max), }));
        }

        #endregion

        #region Statements
        public bool SelectStatement()
        {
            bool Result = false;

            Connector.WrapDataReader(Connector.RunStatement(
                String.Format("SELECT *" +
                               "FROM {0}", CONSTANSTS.RECORDS_TABLES),
                null, out Result), null);

            return Result;
        }
        public bool ClearRecords()
        {
            bool Result = false;

            Connector.WrapDataReader(Connector.RunStatement(
                String.Format("DELETE  FROM {0}", CONSTANSTS.RECORDS_TABLES),
                null, out Result), null);

            return Result;
        }
        #endregion
    }
}
