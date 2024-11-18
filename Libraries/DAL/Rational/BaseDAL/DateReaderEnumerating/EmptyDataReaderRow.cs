using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data.Common;

namespace Maba.DAL.BaseDAL
{
    public class EmptyDataReaderRow : DataReaderRow
    {
        public EmptyDataReaderRow()
            : base(null)
        {

        }
    }
}
