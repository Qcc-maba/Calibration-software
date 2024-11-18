using Maba.DAL.BaseDAL.Records;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml;

namespace Maba.DAL.BaseDAL
{
    public class MSSqlServer : BaseDALConnector
    {
        #region Ctor(s)

        public MSSqlServer(DbProviderFactory providerFactory, DbConnection connectionObj)
            : base(providerFactory, connectionObj)
        {

        }

        public MSSqlServer(string stringConnectionSectionName)
            : base(System.Data.SqlClient.SqlClientFactory.Instance, stringConnectionSectionName)
        {

        }

        #endregion

        #region Overloading from BaseDALConnector

        #region XMLProcedure

        public override XmlReader RunXMLProcedure(string StoredProcedureName, IDataParameter[] parameters, out bool Result)
        {
            Result = false;

            try
            {
                if (!IsConnectionOpen && Open() == DBOpenResults.Failed)
                    return null;

                bool subResult = false;

                DbCommand command = BuildQueryCommand(StoredProcedureName, parameters, out subResult);
                if (subResult && command is System.Data.SqlClient.SqlCommand)
                {
                    command.CommandType = CommandType.StoredProcedure;

                    var xmlReader = ((System.Data.SqlClient.SqlCommand)command).ExecuteXmlReader();
                    //if DbConnectionObj will be closed here, no data can be read...
                    //!!! DON'T !!! Close();  !!! DON'T !!!         
                    Result = true;
                    return xmlReader;
                }
                else
                {
                    Result = false;
                    return null;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
        }

        #endregion

        public override DataReaderEnumerator CreateTableFunctionEnumerator(string TableFunctionName, params IDataParameter[] parameters)
        {
            throw new NotSupportedException();
        }

        #endregion

        #region Hydra Private Methods

        public void GetValFromProc()
        {
            var p = CreateOutParameter("@VARCHAR(50)", -1);
            //var res = GetEntity<CorrectionValues>(GetProcedureEnumerator("GetSensorByName", new IDataParameter[] { p }));
        }
        #endregion
    }
}
