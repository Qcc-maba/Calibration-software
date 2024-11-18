using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data.Common;

namespace Maba.DAL.BaseDAL
{
    public static class SqlDataReaderExtensions
    {
        public static string[] GetDataReaderColumns(this DbDataReader reader)
        {
            int columnsLenght = reader.FieldCount;
            List<string> cols = new List<string>();
            for (int i = 0; i < columnsLenght; i++)
                cols.Add(reader.GetName(i));

            return cols.ToArray();
        }
    }
}
