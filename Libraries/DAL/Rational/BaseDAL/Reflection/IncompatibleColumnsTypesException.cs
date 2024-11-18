using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.DAL.BaseDAL.Reflection
{
    public class IncompatibleColumnTypeException : Exception
    {
        public string DbColumnName { get; internal set; }
        public Type DbColumnType { get; internal set; }
        public Type DbColumnExpectedType { get; internal set; }

        public override string Message
        {
            get
            {
                return String.Format("Incompatible Column Type. Column Name:{0}. Column Type:{1} (Expected:{2})", DbColumnName, DbColumnType, DbColumnExpectedType);
            }
        }
        public IncompatibleColumnTypeException()
            : base()
        {

        }
    }
}
