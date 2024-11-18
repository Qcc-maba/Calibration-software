using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data.Common;

namespace Maba.DAL.BaseDAL
{
    public class DataReaderRow
    {
        #region Properties

        public int? RowIndex { get; internal set; }
        public string[] Columns { get; set; }
        public DbDataReader DataReader { get; private set; }
        public bool isValid { get; private set; }

        #endregion

        #region constructors

        public DataReaderRow(DbDataReader dataReader)
        {
            RowIndex = null;
            DataReader = dataReader;
            isValid = DataReader != null;

            if (isValid)
            {
                Columns = dataReader.GetDataReaderColumns().ToArray();
            }
            else
            {
                Columns = new string[0];
            }
        }

        #endregion
    }
}
