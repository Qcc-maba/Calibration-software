using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL.UnitTest
{
    public static class CONSTANSTS
    {
        //SP
        public const string SELECT_RECORDS_SP = "sp_SelectRecords";
        public const string INSERT_RECORDS_SP = "sp_InsertRecord";
        public const string GET_RESULTINT64_SP = "sp_GetResultInt64";
        public const string GET_RESULTINT32_SP = "sp_GetResultInt32";


        //Function
        public const string SELECT_RECORDS_TABLEFUNCTION = "func_SelectRecords";

        public const string SCALAR_TABLEFUNCTION = "dbo.func_Scalar";

        public const string RECORDS_TABLES = "Records";
    }
}
