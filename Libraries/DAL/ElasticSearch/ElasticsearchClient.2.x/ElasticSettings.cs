using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.ElasticsearchLibrary
{
    public class ElasticSettings
    {
        public enum RollingIndexFormats
        {
            /// <summary>
            /// yyyy.MM.dd
            /// </summary>
            Day,
            /// <summary>
            /// yyyy.MM
            /// </summary>
            Month,
            /// <summary>
            /// yyyy
            /// </summary>
            Year
        }
        #region properties

        public string Server_URL { get; set; }

        /// <summary>
        /// limit number of indexes in searches. when exceeded use *
        /// </summary>
        public int MaxIndexsMultiSearch { get; set; }
        public RollingIndexFormats RollingIndexFormat { get; set; }

        #endregion

        #region ctor

        public ElasticSettings()
        {
            Server_URL = @"http://localhost:9200";
            RollingIndexFormat = RollingIndexFormats.Month;
                
            MaxIndexsMultiSearch = 10;
        }

        #endregion
    }
}
