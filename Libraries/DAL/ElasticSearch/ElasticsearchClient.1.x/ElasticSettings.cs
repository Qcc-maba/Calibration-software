using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.Elasticsearch
{
    public class ElasticSettings
    {
        #region properties

        public string Server_URL { get; set; }

        /// <summary>
        /// limit number of indexes in searches. when exceeded use *
        /// </summary>
        public int MaxIndexsMultiSearch { get; set; }
        public string Elastic_IndexName { get; set; }
        public string Elastic_RollingIndex_DateFormat { get; set; }

        #endregion

        #region ctor

        public ElasticSettings()
        {
            //Server_URL = @"http://localhost.fiddler:9200";
           Server_URL = @"http://localhost:9200";
            Elastic_RollingIndex_DateFormat = "yyyy.MM";

            MaxIndexsMultiSearch = 10;
        }

        #endregion
    }
}
