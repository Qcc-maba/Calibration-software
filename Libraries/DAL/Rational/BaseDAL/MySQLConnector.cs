using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using MySql.Data.MySqlClient;
using System.ComponentModel;

namespace Maba.DAL.BaseDAL
{
    public class MySQLConnector : BaseDALConnector
    {
        #region Ctor(s)

        public MySQLConnector(DbProviderFactory providerFactory, DbConnection connectionObj)
            : base(providerFactory, connectionObj)
        {

        }

        public MySQLConnector(string stringConnection)
            : base(MySql.Data.MySqlClient.MySqlClientFactory.Instance, stringConnection)
        {

        }

        #endregion

        #region XMLProcedure

        public override System.Xml.XmlReader RunXMLProcedure(string StoredProcedureName, System.Data.IDataParameter[] parameters, out bool Result)
        {
            throw new NotImplementedException();
        }

        #endregion

        #region BaseDALConnector override

        public override DataReaderEnumerator CreateTableFunctionEnumerator(string TableFunctionName, params IDataParameter[] parameters)
        {
            throw new NotSupportedException();
        }

        public override DataReaderEnumerator CreateTableFunctionEnumerator(string TableFunctionName, string[] OrderByColumns, params IDataParameter[] parameters)
        {
            throw new NotSupportedException();
        }
        
        public override Reflection.PropertyAssignerAttribute.ConvertorDelegate HasFixedAssigner(Type dbColumnType, Type propertyType)
        {
            if (dbColumnType == typeof(UInt64) && propertyType == typeof(bool))
            {
                return (reader, b, index) =>
                {
                    return reader.GetInt64(index) == 1;
                };
            }
            //if (dbColumnType == typeof(System.SByte) && propertyType == typeof(Byte))
            //{
            //    return (reader, b, index) =>
            //    {
            //        return (Byte)(sbyte)reader.GetValue(index);
            //    };
            //}

            return null;
        }

        #endregion
    }
}
