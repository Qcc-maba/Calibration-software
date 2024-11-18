using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Web.Configuration;
using System.Collections.Generic;

namespace Maba.Connectors.Elasticsearch.Testing
{
    [TestClass]
    public class Elasticsearch_UnitTest
    {
        [TestMethod]
        public void TestInsert()
        {
            var url = WebConfigurationManager.AppSettings["ServerUrl"];
            var indexName = "elasticsearch_unitest";
            var type = "TestRecord";
            var countTestRecord = 100;
            var date = DateTime.Now.AddHours(-2);
            using (var c = new TestConnector(new ElasticSettings() { Server_URL = url }))
            {
                for (int i = 0; i < countTestRecord; i++)
                {
                    c.InsertRecord(indexName, type, new TestRecord() { id = i, name = "name_" + i.ToString(), Date = date });
                    date = date.AddHours(1);
                }

                for (int i = 0; i < countTestRecord; i++)
                {
                    //      getcTestRecord += c.GetSearch(DateTime.Now.AddHours(-24), DateTime.Now.AddHours(countTestRecord + 10), indexName, type, "1", 1, countTestRecord).TotalRecords;
                }

                Assert.IsTrue(countTestRecord == 6 + countTestRecord);

            }


        }

        [TestMethod]
        public void TestBulk()
        {
            var url = WebConfigurationManager.AppSettings["ServerUrl"];
            var indexName = "admin";
            var type = "user";
            var now = DateTime.Now;
            List<TestRecord> testList = new List<TestRecord>();

            for (int i = 0; i < 20; i++)
            {
                testList.Add(new TestRecord() { Date = now, id = i, name = "Name" + i.ToString() });
            }
            using (var c = new TestConnector(new ElasticSettings() { Server_URL = url }))
            {
                c.IndexName = indexName;

                c.Bullk(indexName, type, testList);
            }
        }
    }
}
