using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.DAL.BaseDAL.UnitTest
{
    [TestClass]
    public class DAL_MySQLTester : BaseUnitTest_DbConnector
    {
        public DAL_MySQLTester()
            : base("MySQLConnector")
        {
        }

        [TestMethod]
        [ExpectedException(typeof(NotImplementedException))]
        public override void TableFunction()
        {
            throw new NotImplementedException();
        }
    }
}
