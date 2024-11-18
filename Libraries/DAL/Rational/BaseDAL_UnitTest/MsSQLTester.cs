using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.DAL.BaseDAL.UnitTest
{
    [TestClass]
    public class DAL_MsSQLTester : BaseUnitTest_DbConnector
    {
        public DAL_MsSQLTester()
            : base("KyulanSyncDB")
        {
        }
    }
}
