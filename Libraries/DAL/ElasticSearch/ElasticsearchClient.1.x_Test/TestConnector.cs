using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.Elasticsearch.Testing
{
    public class TestConnector : BaseElasticsearchConnectorVer_1x
    {
        public TestConnector(ElasticSettings Settings)
            : base(Settings)
        {
            IndexName = "admin";
        }
        internal void InsertRecord(string indexName, string type, TestRecord testRecord)
        {
            InsertRecord<TestRecord>(indexName, type, testRecord);
        }

        public string tostringIndexName(TestRecord i)
        {
            return IndexName;
        }

        public string IdGenerator(TestRecord i)
        {
            return i.id.ToString();
        }
        
        internal void Bullk(string indexName, string type, List<TestRecord> testList)
        {
           var t= BullkCreate<TestRecord>(type, tostringIndexName, testList,IdGenerator);
        }

        //public LoggerResponse<TestRecord> GetSearch(DateTime? from, DateTime to, string indexName, string type, string RoutingId, int pageSize, int pageNum ) 
        //{
        //    return GetSearch<TestRecord>(from, to, indexName, type, RoutingId, pageSize, pageNum, null, null);
        //}

        public void delete(string name)
        {
            if ("reza" == name)
            {
                DeleteIndex("*");
            }
            else
                DeleteIndex(name);
        }
        public string IndexName { get; set; }
    }
}
