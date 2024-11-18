using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Web.Configuration;
using System.Collections.Generic;
using Maba.Connectors.ElasticsearchLibrary;
using Nest;

using FF = Elasticsearch.Net;

namespace Maba.Connectors.Elasticsearch.Testing
{
    [TestClass]
    public class Elasticsearch_UnitTest2x
    {
        #region private methods
        private void CompareRecords(BaseElasticsearchConnector_2x connector, TestRecord[] records1, TestRecord[] records2)
        {
            Assert.AreEqual(records1.Length, records2.Length);

            for (int i = 0; i < records1.Length; i++)
            {
                Assert.AreEqual(records1[i].ID, records2[i].ID);
                Assert.AreEqual(records1[i].name, records2[i].name);
                Assert.AreEqual(records1[i].Number1, records2[i].Number1);
                Assert.AreEqual(records1[i].Number2, records2[i].Number2);
                Assert.AreEqual(records1[i].RecordDate, records2[i].RecordDate);
            }
        }
        private TestRecord[] CreateRecords(int capacity)
        {
            var records = new TestRecord[capacity];
            var now = DateTime.Now;
            for (int i = 0; i < capacity; i++)
            {
                records[i] = new TestRecord(now)
                {
                    ID = Guid.NewGuid().ToString(),
                    name = $"My Name_{i}",
                    Number1 = 10 + (i % 10),
                    Number2 = 900 + i,
                    Number3_SortUp = i * i,
                    Number3_SortDown = 900 - (i * i)
                };
                now += TimeSpan.FromMinutes(1);
            }

            return records;
        }

        private void WaitForRecords(BaseElasticsearchConnector_2x connector, int len, string indexName)
        {
            int attempt = 0;
            while (true)
            {
                attempt++;

                Assert.IsTrue(attempt < 10);

                System.Threading.Thread.Sleep(200);

                var waitResponse = connector.Search<TestRecord>(Indices.Index(indexName), Types.All);

                if (waitResponse.IsValid && waitResponse.HitsMetaData.Total == len)
                    break;
            }
        }

        private BaseElasticsearchConnector_2x CreateConnector()
        {
            ElasticSettings settings = new ElasticSettings()
            {
                Server_URL = @"http://localhost.fiddler:9200"
                // Server_URL = @"http://localhost:9200"

            };

            var connector = new BaseElasticsearchConnector_2x(settings);

            return connector;
        }

        //testing exact searching indexes
        [TestMethod]
        public void Elastic2x_IsExistsAndDeleteIndex1()
        {
            var connector = this.CreateConnector();

            string indexName = $"testIndex-{Guid.NewGuid().ToString()}".ToLower();

            //not exists before creation
            var exists1Response = connector.IsIndexExists(Indices.Index(indexName));
            Assert.IsFalse(exists1Response.Exists);

            //create
            var createResponse = connector.CreateIndex(indexName);
            Assert.IsTrue(createResponse.IsValid);
            Assert.IsTrue(connector.IsIndexExists(Indices.Index(indexName)).Exists);


            var deleteResponse = connector.DeleteIndex(indexName);
            Assert.IsTrue(deleteResponse.IsValid);

            //not exists after deletion
            var exists2Response = connector.IsIndexExists(Indices.Index(indexName));
            Assert.IsFalse(exists2Response.Exists);
        }

        //testing wild-cards searching indexes
        [TestMethod]
        public void Elastic2x_IsExistsAndDeleteIndex2()
        {
            var connector = this.CreateConnector();

            string indexNameTemplate = $"testIndex-{Guid.NewGuid().ToString()}".ToLower();

            #region create indexes

            var indices = new string[3];
            for (int i = 0; i < indices.Length; i++)
            {
                indices[i] = indexNameTemplate + $"_{i}";
            }

            #endregion

            //ALL - indexes shouldn't be exists
            for (int i = 0; i < indices.Length; i++)
            {
                Assert.IsFalse(connector.IsIndexExists(Indices.Index(indices[i])).Exists);
            }

            //create indexes and test
            for (int i = 0; i < indices.Length; i++)
            {
                var createResponse = connector.CreateIndex(indices[i]);
                Assert.IsTrue(createResponse.IsValid);
                Assert.IsTrue(connector.IsIndexExists(Indices.Index(indices[i])).Exists);
            }

            //search as exact - should be false
            Assert.IsFalse(connector.IsIndexExists(Indices.Parse(indexNameTemplate)).Exists);

            //search as wild-card - should be true
            var exists_request1 = connector.IsIndexExists(Indices.Parse(indexNameTemplate + "*"));
            Assert.IsTrue(exists_request1.Exists);

            //search as wild-card - should be true
            var exists_request2 = connector.IsIndexExists(Indices.Parse(indexNameTemplate),
                r =>
                {
                    r.ExpandWildcards = FF.ExpandWildcards.All;
                });

            Assert.IsTrue(exists_request1.Exists);
        }

        private void DeleteIfExists(BaseElasticsearchConnector_2x connector, string indexName)
        {
            if (connector.IsIndexExists(Indices.Parse(indexName)).Exists)
            {
                var response = connector.DeleteIndex(indexName);
            }
        }

        #endregion

        [TestMethod]
        public void Elastic2x_TestRollingIndexBuiding()
        {
            DateTime from = new DateTime(2000, 1, 10);
            DateTime to = from;
            string baseIndexName = "myIndex_";

            var connector = CreateConnector();

            #region Day format 

            var format = ElasticSettings.RollingIndexFormats.Day;

            //single day
            from = new DateTime(2000, 1, 10);
            Assert.AreEqual($"{baseIndexName}_20000110", connector.BuildIndexName(baseIndexName, from, from, format));
            Assert.AreEqual($"{baseIndexName}_20000110", connector.BuildIndexName(baseIndexName, from, format));

            //3 days
            var indicies_3days = $"{baseIndexName}_20000110,"
                                + $"{baseIndexName}_20000111,"
                                + $"{baseIndexName}_20000112,"
                                + $"{baseIndexName}_20000113,";
            to = from.AddDays(3);
            Assert.AreEqual(indicies_3days, connector.BuildIndexName(baseIndexName, from, to, format));

            //entire month
            from = new DateTime(2000, 5, 1);
            to = new DateTime(2000, 6, 5);
            var indicies_entireMonth = $"{baseIndexName}_200005*,"
                                + $"{baseIndexName}_20000601,"
                                + $"{baseIndexName}_20000602,"
                                + $"{baseIndexName}_20000603,"
                                + $"{baseIndexName}_20000604,"
                                + $"{baseIndexName}_20000605";
            Assert.AreEqual(indicies_entireMonth, connector.BuildIndexName(baseIndexName, from, to, format));

            #endregion

            #region Month format 

            format = ElasticSettings.RollingIndexFormats.Month;

            //single month
            from = to = new DateTime(2000, 1, 10);
            Assert.AreEqual($"{baseIndexName}_200001", connector.BuildIndexName(baseIndexName, from, to, format));
            Assert.AreEqual($"{baseIndexName}_200001", connector.BuildIndexName(baseIndexName, from, format));

            //3 days
            var indicies_3month = $"{baseIndexName}_200001,"
                                + $"{baseIndexName}_200002,"
                                + $"{baseIndexName}_200003,"
                                + $"{baseIndexName}_200004";
            to = from.AddMonths(3);
            Assert.AreEqual(indicies_3month, connector.BuildIndexName(baseIndexName, from, to, format));

            //entire year
            from = new DateTime(2000, 1, 4);
            to = new DateTime(2001, 5, 5);
            var indicies_entireYear = $"{baseIndexName}_2000*,"
                                + $"{baseIndexName}_200101,"
                                + $"{baseIndexName}_200102,"
                                + $"{baseIndexName}_200103,"
                                + $"{baseIndexName}_200104,"
                                + $"{baseIndexName}_200105";
            Assert.AreEqual(indicies_entireYear, connector.BuildIndexName(baseIndexName, from, to, format));

            #endregion

        }

        [TestMethod]
        public void Elastic2x_TestInsert()
        {
            string testType = "mytype_TestInsert".ToLower();
            string indexName = "myindex_TestInsert".ToLower();

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName + "*");

            var now = DateTime.Now;
            var record = CreateRecords(1)[0];

            for (int i = 0; i < 10; i++)
            {
                var response = connector.IndexRecord(
                                                        //index
                                                        connector.BuildIndexName(indexName, DateTime.Now),
                                                        //type
                                                        testType,
                                                        //record object
                                                        record,
                                                        //modify request action
                                                        r => Assert.IsNotNull(r),
                                                        //record id
                                                        record.ID);

                Assert.AreEqual(i == 0, response.Created);
                Assert.IsTrue(response.IsValid);
                Assert.IsNull(response.ServerError);
                Assert.AreEqual(response.Version, i + 1);
            }
        }

        [TestMethod]
        public void Elastic2x_TestBulkAndSearch_Term()
        {
            string testType = "mytype_Search".ToLower();
            string indexName = "myindex_TestBulkAndSearch_Term".ToLower();

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName + "*");

            #region create records

            var records = CreateRecords(100);

            for (int i = 0; i < records.Length; i++)
            {
                records[i].Number1 = i % 3;
            }

            #endregion

            var createResponse = connector.BullkCreate<TestRecord>(
                                        //index name
                                        r => connector.BuildIndexName(indexName, r.RecordDate),
                                        r => testType,
                                        //records
                                        records,
                                        //id
                                        r => r.ID,
                                         //routing
                                         r => null);

            Assert.IsNotNull(createResponse);
            Assert.IsTrue(createResponse.IsValid);
            Assert.IsTrue(createResponse.Items.All(a => a.IsValid));

            WaitForRecords(connector, records.Length, indexName + "*");

            for (int i = 0; i < 3; i++)
            {
                //get back using Term
                var result = connector.Search<TestRecord>(
                                 //index
                                 indexName + "*",
                                 //type
                                 testType,
                                 null,
                                 r =>
                                   {
                                       r.Size = 1000;
                                       connector.Search_Term(r, "number1", i);
                                   }
                                 );
                var hits = result.Hits
                    .Select(r => r.Source)
                    .OrderBy(r => r.ID)
                        .ToArray();

                var expectedResults = records
                    .Where(r => r.Number1 == i)
                    .OrderBy(r => r.ID)
                    .ToArray();

                Assert.AreEqual(expectedResults.Length, hits.Length);
                CompareRecords(connector, expectedResults, hits);
            }
        }

        [TestMethod]
        public void Elastic2x_TestBulkAndSearch_Match()
        {
            string testType = "mytype_Search".ToLower();
            string indexName = "myindex_TestBulkAndSearch_Term".ToLower();

            var values = new string[] { "ONE1"+Guid.NewGuid().ToString(),
                                        "TWO2"+Guid.NewGuid().ToString(),
                                        "THREE3"+Guid.NewGuid().ToString() };

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName + "*");

            #region create records

            var records = CreateRecords(100);

            for (int i = 0; i < records.Length; i++)
            {
                records[i].data = values[i % values.Length];
                records[i].Number1 = i % values.Length;
            }

            #endregion

            var createResponse = connector.BullkCreate<TestRecord>(
                                        //index name
                                        r => connector.BuildIndexName(indexName, r.RecordDate),
                                        r => testType,
                                        //records
                                        records,
                                        //id
                                        r => r.ID,
                                         //routing
                                         r => null);

            Assert.IsNotNull(createResponse);
            Assert.IsTrue(createResponse.IsValid);
            Assert.IsTrue(createResponse.Items.All(a => a.IsValid));

            WaitForRecords(connector, records.Length, indexName + "*");

            for (int i = 0; i < values.Length; i++)
            {
                //get back using Term
                var result = connector.Search<TestRecord>(
                                 //index
                                 indexName + "*",
                                 //type
                                 testType,
                                 null,
                                 r =>
                                 {
                                     r.Size = 1000;
                                     connector.SearchMatch(r, "data", values[i]);
                                 }
                                 );
                var hits = result.Hits
                    .Select(r => r.Source)
                    .OrderBy(r => r.ID)
                        .ToArray();

                var expectedResults = records
                    .Where(r => r.Number1 == i)
                    .OrderBy(r => r.ID)
                    .ToArray();

                Assert.AreEqual(expectedResults.Length, hits.Length);
                CompareRecords(connector, expectedResults, hits);
            }
        }

        /// <summary>
        /// Inserting using 2 routes.
        /// Since 2 routes can be stored in same node, we will separate results by filed Number1
        /// </summary>
        [TestMethod]
        public void Elastic2x_TestInsert_withRouting()
        {
            string testType = "mytype_TestInsert".ToLower();
            string indexName = "myindex_TestInsert_withRouting".ToLower();

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName + "*");

            var now = DateTime.Now;
            var records = CreateRecords(10);

            var routing_groups = new string[] { "EVEN", "ODD" };
            var routing_values = new long[] { 10, 20 };

            #region prepare records routings (2 groups)

            for (int i = 0; i < records.Length; i++)
            {
                records[i].data = i % 2 == 0 ? routing_groups[0] : routing_groups[1];
                records[i].Number1 = i % 2 == 0 ? routing_values[0] : routing_values[1];
            }

            #endregion

            #region insert records. data property as routing

            for (int i = 0; i < records.Length; i++)
            {
                var record = records[i];

                var response = connector.IndexRecord(
                                                        //index
                                                        connector.BuildIndexName(indexName, DateTime.UtcNow),
                                                        //type
                                                        testType,
                                                        //record object
                                                        record,
                                                        //modify request action
                                                        r => Assert.IsNotNull(r),
                                                        //record id
                                                        record.ID,
                                                        //routing
                                                        record.data);

                Assert.IsTrue(response.Created);
                Assert.IsTrue(response.IsValid);
                Assert.IsNull(response.ServerError);
                Assert.AreEqual(response.Version, 1);
            }

            #endregion

            WaitForRecords(connector, records.Length, indexName + "*");

            #region testing getting back the records

            for (int i = 0; i < routing_groups.Length; i++)
            {
                var records_expected = records
                                    .Where(r => r.Number1 == routing_values[i] && r.data == routing_groups[i])
                                    .OrderBy(r => r.Number3_SortUp)
                                    .ToArray();

                var records_result = connector.Search<TestRecord>(
                                                    //indexes
                                                    Indices.Index(indexName + "*"),
                                                    //types
                                                    testType,
                                                    //hit result modify
                                                    (r, record) =>
                                                    {

                                                    },
                                                    //search request modify
                                                    r =>
                                                    {
                                                        r.Routing = new string[] { routing_groups[i] };
                                                        connector.Search_Term(r, "number1", routing_values[i]);
                                                    });


                var hits = records_result.Hits
                                        .OrderBy(r => r.Source.Number3_SortUp)
                                        .ToArray();

                Assert.AreEqual(records_expected.Length, hits.Length);

                for (int j = 0; j < records_expected.Length; j++)
                {
                    Assert.IsNotNull(hits[j]);
                    Assert.IsNotNull(hits[j].Source);

                    //compare to expected
                    Assert.AreEqual(hits[j].Source.name, records_expected[j].name);
                    Assert.AreEqual(hits[j].Source.data, records_expected[j].data);

                    Assert.AreEqual(hits[j].Source.ID, records_expected[j].ID);
                    Assert.AreEqual(hits[j].Source.Number1, records_expected[j].Number1);
                    Assert.AreEqual(hits[j].Source.Number2, records_expected[j].Number2);
                    Assert.AreEqual(hits[j].Source.Number3_SortDown, records_expected[j].Number3_SortDown);
                    Assert.AreEqual(hits[j].Source.Number3_SortUp, records_expected[j].Number3_SortUp);
                }
            }

            #endregion
        }

        [TestMethod]
        public void Elastic2x_TestBulkIndex()
        {
            string testType = "mytype_TestBulkIndex".ToLower();
            string indexName = "myindex_TestBulkIndex".ToLower();

            var connector = CreateConnector();

            //first - delete this index
            this.DeleteIfExists(connector, indexName);
            var records = CreateRecords(100);

            IBulkResponse response = null;

            for (int operationIndex = 0; operationIndex < 2; operationIndex++)
            {
                response = connector.BullkIndex(r => indexName,             //index
                                                r => testType,
                                                records,
                                                r => r.ID,                  //id of record
                                                r => r.Number1.ToString()   //routing
                                                );

                Assert.IsTrue(response.IsValid);
                var items = response.Items.ToArray();
                Assert.AreEqual(items.Length, records.Length);

                for (int i = 0; i < items.Length; i++)
                {
                    Assert.IsTrue(items[i].IsValid);
                    Assert.IsTrue(200 <= items[i].Status && items[i].Status < 300);
                    Assert.AreEqual(items[i].Operation, operationIndex == 0 ? "index" : "index");
                    Assert.AreEqual(items[i].Version, operationIndex + 1);
                    Assert.AreEqual(items[i].Id, records[i].ID);
                    Assert.IsNull(items[i].Error);
                }
            }

            WaitForRecords(connector, records.Length, indexName);

            //get ALL records back
            for (int i = 0; i < records.Length; i++)
            {
                var record = connector.GetByID<TestRecord>(indexName, testType,
                    records[i].ID,
                    r => r.Fields = new string[] { BaseElasticsearchConnector_2x.ELASTIC_HIT__FIELD_NAME_SOURCE, "_score" },
                    (hit, r) =>
                    {
                    },
                    records[i].Number1.ToString());

                Assert.AreEqual(record.Id, records[i].ID);
                Assert.AreEqual(record.Source.ID, records[i].ID);
                Assert.AreEqual(record.Source.name, records[i].name);
                Assert.AreEqual(record.Source.Number1, records[i].Number1);
                Assert.AreEqual(record.Source.Number2, records[i].Number2);
                Assert.AreEqual(record.Source.RecordDate, records[i].RecordDate);
            }
        }

        [TestMethod]
        public void Elastic2x_TestBulkAndSearch()
        {
            string testType = "mytype_TestBulkAndSearch".ToLower();
            string indexName = "myindex_TestBulkAndSearch".ToLower();

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName);

            var records = CreateRecords(100);

            TestRecord[] expectedRecords = null;

            int minRecordsIndex = 50;
            int maxRecordsIndex = 50;
            //page size should be in not whole divide of entire records (to force last page to be smaller)
            int pageSize = 23;

            #region bulk index these records

            IBulkResponse response = null;

            for (int operationIndex = 0; operationIndex < 2; operationIndex++)
            {
                response = connector.BullkIndex(r => indexName,             //index
                                                r => testType,
                                                records,
                                                r => r.ID,                  //id of record
                                                r => r.Number1.ToString()   //routing
                                                );

                Assert.IsTrue(response.IsValid);
                var items = response.Items.ToArray();
                Assert.AreEqual(items.Length, records.Length);

                for (int i = 0; i < items.Length; i++)
                {
                    Assert.IsTrue(items[i].IsValid);
                    Assert.IsTrue(200 <= items[i].Status && items[i].Status < 300);
                    Assert.AreEqual(items[i].Operation, operationIndex == 0 ? "index" : "index");
                    Assert.AreEqual(items[i].Version, operationIndex + 1);
                    Assert.AreEqual(items[i].Id, records[i].ID);
                    Assert.IsNull(items[i].Error);
                }
            }

            #endregion

            WaitForRecords(connector, records.Length, indexName);

            #region test paging & sorting (over number)

            for (int i = 0; i < 16; i++)
            {
                var result = connector.Search<TestRecord>(Indices.Index(indexName + "*"), Types.Type(testType),
                null,
                r =>
                {
                    switch (i % 4)
                    {
                        case 0:
                            connector.Search_SortColumns<TestRecord>(r, "number3_SortDown ASC");

                            expectedRecords = records
                                   .OrderBy(d => d.Number3_SortDown)
                                   .Skip(pageSize * i)
                                   .Take(pageSize)
                                   .ToArray();
                            break;
                        case 1:
                            connector.Search_SortColumns<TestRecord>(r, "number3_SortDown DESC");

                            expectedRecords = records
                                   .OrderByDescending(d => d.Number3_SortDown)
                                   .Skip(pageSize * i)
                                   .Take(pageSize)
                                   .ToArray();
                            break;
                        case 2:
                            connector.Search_SortColumns<TestRecord>(r, "number3_SortUp ASC");

                            expectedRecords = records
                                   .OrderBy(d => d.Number3_SortUp)
                                   .Skip(pageSize * i)
                                   .Take(pageSize)
                                   .ToArray();
                            break;
                        case 3:
                            connector.Search_SortColumns<TestRecord>(r, "number3_SortUp DESC");

                            expectedRecords = records
                                   .OrderByDescending(d => d.Number3_SortUp)
                                   .Skip(pageSize * i)
                                   .Take(pageSize)
                                   .ToArray();
                            break;
                    }
                    connector.Search_Paging(r, pageSize, i + 1);
                    //sort on Number3_SortDown as Up
                }
                );

                Assert.IsTrue(result.IsValid);
                var returnedRecords = result.Hits
                    .Select(h => h.Source)
                    .ToArray();



                CompareRecords(connector, returnedRecords, expectedRecords);
            }

            #endregion

            #region test paging & sorting (multiple)

            int MaxPage = records.Length / pageSize + ((records.Length % pageSize == 0) ? 0 : 1);
            for (int i = 0; i < MaxPage + 2; i++)
            {
                var result = connector.Search<TestRecord>(Indices.Index(indexName + "*"), Types.Type(testType),
                null, r =>
                 {
                     r.Fields = new string[] { BaseElasticsearchConnector_2x.ELASTIC_HIT__FIELD_NAME_SOURCE, "_timestamp" };

                     connector.Search_Paging(r, pageSize, i + 1);
                     connector.Search_SortColumns<TestRecord>(r, "recordDateT DESC, number2 ASC");
                 });

                Assert.IsTrue(result.IsValid);
                var returnedRecords = result.Hits
                    .Select(h => h.Source)
                    .ToArray();

                expectedRecords = records
                                            .OrderByDescending(r => r.RecordDate)
                                            .ThenBy(r => r.Number2)
                                            .Skip(pageSize * i)
                                            .Take(pageSize)
                                            .ToArray();

                CompareRecords(connector, returnedRecords,
                                       expectedRecords);
            }

            #endregion

            #region range  (numbers :: 1 boundary, 2 boundary, no boundaries)

            for (int i = 0; i < 20; i++)
            {
                var result = connector.Search<TestRecord>(Indices.Index(indexName + "*"), Types.Type(testType),
                null, r =>
                 {
                     #region switch case

                     switch (i % 10)
                     {
                         case 0:
                         case 1:
                         case 2:
                         case 3:
                             minRecordsIndex = 50 - (i * 2);
                             maxRecordsIndex = 50 + (i * 2);

                             connector.Search_BuildRange<TestRecord>(r, "number2", minRecordsIndex, maxRecordsIndex);
                             expectedRecords = records
                                         .Where(d => minRecordsIndex <= d.Number2 && d.Number2 <= maxRecordsIndex)
                                         .OrderBy(d => d.Number2)
                                         .ToArray();
                             break;
                         case 4:
                         case 5:
                         case 6:
                             maxRecordsIndex = 50 + (i * 2);

                             connector.Search_BuildRange<TestRecord>(r, "number2", null, maxRecordsIndex);
                             expectedRecords = records
                                         .Where(d => d.Number2 <= maxRecordsIndex)
                                         .OrderBy(d => d.Number2)
                                         .ToArray();
                             break;
                         default:
                         case 7:
                         case 8:
                         case 9:
                             minRecordsIndex = 50 - (i * 2);

                             connector.Search_BuildRange<TestRecord>(r, "number2", minRecordsIndex, null);
                             expectedRecords = records
                                         .Where(d => minRecordsIndex <= d.Number2)
                                         .OrderBy(d => d.Number2)
                                         .ToArray();
                             break;
                     }
                     #endregion

                     r.Size = 10000;

                     connector.Search_SortColumns<TestRecord>(r, "number2 ASC");
                 });

                Assert.IsTrue(result.IsValid);

                var returnedRecords = result.Hits
                                            .Select(h => h.Source)
                                            .ToArray();

                CompareRecords(connector, returnedRecords, expectedRecords);
            }

            #endregion

            #region range  (date :: 1 boundary, 2 boundary, no boundaries)

            DateTime minD, maxD;

            for (int i = 0; i < 20; i++)
            {
                var result = connector.Search<TestRecord>(Indices.Index(indexName + "*"), Types.Type(testType),
                null, r =>
                 {
                     r.Size = 10000;

                     #region switch case

                     switch (i % 10)
                     {
                         case 0:
                         case 1:
                         case 2:
                         case 3:
                             minD = records[Math.Max(0, 50 - i)].RecordDate;
                             maxD = records[Math.Min(records.Length, 50 + i)].RecordDate;

                             expectedRecords = records
                                             .Where(d => minD <= d.RecordDate && d.RecordDate <= maxD)
                                             .OrderBy(d => d.Number2)
                                             .ToArray();

                             connector.Search_BuildRange<TestRecord>(r, "recordDateT", minD, maxD);
                             break;
                         case 4:
                         case 5:
                         case 6:
                             minD = records[Math.Max(0, 50 - i)].RecordDate;
                             maxD = records[Math.Min(records.Length, 50 + i)].RecordDate;

                             expectedRecords = records
                                             .Where(d => d.RecordDate <= maxD)
                                             .OrderBy(d => d.Number2)
                                             .ToArray();

                             connector.Search_BuildRange<TestRecord>(r, "recordDateT", null, maxD);
                             break;
                         case 7:
                         case 8:
                         case 9:
                         default:
                             minD = records[Math.Max(0, 50 - i)].RecordDate;
                             maxD = records[Math.Min(records.Length, 50 + i)].RecordDate;

                             expectedRecords = records
                                             .Where(d => minD <= d.RecordDate)
                                             .OrderBy(d => d.Number2)
                                             .ToArray();

                             connector.Search_BuildRange<TestRecord>(r, "recordDateT", minD, null);
                             break;
                     }


                     #endregion

                     connector.Search_SortColumns<TestRecord>(r, "number2 ASC");
                 });

                Assert.IsTrue(result.IsValid);

                var returnedRecords = result.Hits
                    .Select(h => h.Source)
                    .ToArray();

                CompareRecords(connector, returnedRecords, expectedRecords);
            }

            #endregion
        }

        [TestMethod]
        public void Elastic2x_TestSearch_Location()
        {
            string testType = "mytype_Search_Location".ToLower();
            string indexName = "myindex_Search_Location".ToLower();

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName);

            var records = CreateRecords(100);

            double start_lat = 40;
            double start_lon = 40;

            //change locations to be sorted by
            for (int i = 0; i < records.Length; i++)
            {
                //Number1 will be used as distance. first index will be the closest. lat index the most far away.
                records[i].Number1 = i;
                records[i].Location = new Location()
                {
                    lat = start_lat + (i * 0.010),
                    lon = start_lon + (i * 0.010)
                };
            }

            #region bulk index these records

            IBulkResponse response = null;

            for (int operationIndex = 0; operationIndex < 2; operationIndex++)
            {
                response = connector.BullkIndex(r => indexName,             //index
                                                r => testType,
                                                records,
                                                r => r.ID,                  //id of record
                                                r => r.Number1.ToString()   //routing
                                                );

                Assert.IsTrue(response.IsValid);
                var items = response.Items.ToArray();
                Assert.AreEqual(items.Length, records.Length);

                for (int i = 0; i < items.Length; i++)
                {
                    Assert.IsTrue(items[i].IsValid);
                    Assert.IsTrue(200 <= items[i].Status && items[i].Status < 300);
                    Assert.AreEqual(items[i].Operation, operationIndex == 0 ? "index" : "index");
                    Assert.AreEqual(items[i].Version, operationIndex + 1);
                    Assert.AreEqual(items[i].Id, records[i].ID);
                    Assert.IsNull(items[i].Error);
                }
            }

            #endregion

            WaitForRecords(connector, records.Length, indexName);

            double search_lat;
            double search_lon;
            int pageSize = 17;

            #region sort by location distance DESC

            search_lat = records[0].Location.lat;
            search_lon = records[0].Location.lon;

            //page size should be in not whole divide of entire records (to force last page to be smaller)
            var records_ASC = connector.Search<TestRecord>(Indices.Index(indexName + "*"), Types.Type(testType),
                      //records modify      
                      (hit, r) =>
                      {
                          r.Distance = (double)hit.Sorts.Last();
                      },
                      //request modify
                      r =>
                      {
                          r.Fields = new string[] { BaseElasticsearchConnector_2x.ELASTIC_HIT__FIELD_NAME_SOURCE, "_timestamp" };
                          connector.Search_Location_SortLocation<TestRecord>(r, "location", search_lat, search_lon, DistanceUnit.Kilometers, SortOrder.Descending);
                          r.Size = pageSize;
                      });

            Assert.IsTrue(records_ASC.IsValid);

            var recoprdsBack_ASC = records_ASC.Hits
                                        .Select(h => h.Source)
                                        .ToArray();

            var recordsBack_expected = records
                                    .OrderByDescending(r => r.Number1)
                                    .Take(pageSize)
                                    .ToArray();

            CompareRecords(connector, recoprdsBack_ASC,
                                   recordsBack_expected);


            #endregion

            #region sort by location distance DESC

            search_lat = records[0].Location.lat;
            search_lon = records[0].Location.lon;

            //page size should be in not whole divide of entire records (to force last page to be smaller)
            var records_DESC = connector.Search<TestRecord>(Indices.Index(indexName + "*"), Types.Type(testType),
                      //records modify      
                      (hit, r) =>
                      {
                          r.Distance = (double)hit.Sorts.Last();
                      },
                      //request modify
                      r =>
                      {
                          r.Fields = new string[] { BaseElasticsearchConnector_2x.ELASTIC_HIT__FIELD_NAME_SOURCE, "_timestamp" };
                          connector.Search_Location_SortLocation<TestRecord>(r, "location", search_lat, search_lon, DistanceUnit.Kilometers, SortOrder.Descending);
                          r.Size = pageSize;
                      });

            Assert.IsTrue(records_DESC.IsValid);

            var recordsBack_DESC = records_DESC.Hits
                                        .Select(h => h.Source)
                                        .ToArray();

            var recordsBack_DESC_expected = records
                                    .OrderByDescending(r => r.Number1)
                                    .Take(pageSize)
                                    .ToArray();

            CompareRecords(connector, recordsBack_DESC_expected,
                                   recordsBack_DESC);


            #endregion
        }


        [TestMethod]
        public void Elastic2x_TestBulkCreate()
        {
            string testType = "mytype_TestBulkCreate".ToLower();
            string indexName = "myindex_TestBulkCreate".ToLower();

            var connector = CreateConnector();
            this.DeleteIfExists(connector, indexName);

            #region create records

            var records = CreateRecords(100);

            #endregion

            IBulkResponse response = null;
            response = connector.BullkCreate(r => indexName,                //index
                                                r => testType,
                                                records,
                                                r => r.ID,                  //id of record
                                                r => r.Number1.ToString()   //routing
                                                );

            Assert.IsTrue(response.IsValid);
            BulkResponseItemBase[] items = response.Items.ToArray();
            Assert.AreEqual(items.Length, records.Length);

            for (int i = 0; i < items.Length; i++)
            {
                Assert.IsTrue(items[i].IsValid);
                Assert.IsTrue(200 <= items[i].Status && items[i].Status < 300);
                Assert.AreEqual(items[i].Operation, "create");
                Assert.AreEqual(items[i].Version, 1);
                Assert.AreEqual(items[i].Id, records[i].ID);
                Assert.IsNull(items[i].Error);
            }

            WaitForRecords(connector, records.Length, indexName);

            #region expected failures for exists records

            var anotherRecords = new TestRecord[records.Length];
            int countSameRecords = 0;

            for (int factor = 0; factor < 10; factor++)
            {
                countSameRecords = 0;

                records.CopyTo(anotherRecords, 0);
                for (int i = 0; i < records.Length; i++)
                {
                    if (factor > 0 && i % factor == 0)
                    {
                        //new records
                        anotherRecords[i] = new TestRecord(anotherRecords[i].RecordDate.AddYears(1))
                        {
                            ID = Guid.NewGuid().ToString(),
                            name = $"My Name_{factor}",
                            Number1 = 10 + (factor % 10),
                            Number2 = 900 + factor
                        };
                    }
                    else
                    {
                        anotherRecords[i] = records[i];
                        countSameRecords++;
                    }
                }


                response = connector.BullkCreate(
                                        r => indexName,                //index
                                        r => testType,
                                        anotherRecords,
                                        r => r.ID,                  //id of record
                                        r => r.Number1.ToString()   //routing
                                        );

                Assert.AreEqual(countSameRecords == 0, response.IsValid);
                items = response.Items.ToArray();
                Assert.AreEqual(items.Length, records.Length);

                //only countSameRecords will return as not valid
                Assert.AreEqual(items.Count(c => c.Error != null), countSameRecords);

                for (int i = 0; i < records.Length; i++)
                {
                    Assert.AreEqual(items[i].Operation, "create");
                    Assert.AreEqual(items[i].Id, anotherRecords[i].ID);

                    if (factor > 0 && i % factor == 0)
                    {
                        //new record should be ok
                        Assert.IsTrue(items[i].IsValid);
                        Assert.IsTrue(200 <= items[i].Status && items[i].Status < 300);
                        Assert.AreEqual(items[i].Version, 1);
                        Assert.IsNull(items[i].Error);
                    }
                    else
                    {
                        //old record and expected as failure
                        Assert.IsFalse(items[i].IsValid);
                        Assert.IsFalse(200 <= items[i].Status && items[i].Status < 300);

                        Assert.AreEqual(items[i].Version, 0);
                        Assert.IsNotNull(items[i].Error);
                    }
                }
            }

            #endregion

        }
    }
}
