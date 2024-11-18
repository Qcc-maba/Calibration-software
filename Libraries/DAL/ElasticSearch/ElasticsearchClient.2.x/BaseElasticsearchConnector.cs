using Nest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.ElasticsearchLibrary
{
    public class BaseElasticsearchConnector_2x : IDisposable
    {
        #region CONSTANTS

        public const long DATETIME_UNIX_1970_1JAN = 621355968000000000;
        public const string ELASTIC_HIT__FIELD_NAME_SOURCE = "_source";

        public const string ELASTIC_SORT_ASCENDING = "ASC";
        public const string ELASTIC_SORT_DESCENDING = "DESC";

        #endregion

        #region members

        protected ElasticClient _Client { get; private set; }

        #endregion

        #region properties

        public ElasticSettings CurrentSettings { get; private set; }

        #endregion

        #region ctor

        public BaseElasticsearchConnector_2x(ElasticSettings settings)
        {
            CurrentSettings = settings;
            //Elasticsearch.Net.els
            var f = new ConnectionSettings(new Uri(CurrentSettings.Server_URL));
            _Client = new ElasticClient(f);
        }

        #endregion

        #region public accessories methods
        public Models.HitRecord[] Convert(IBulkResponse bulkRespose)
        {
            if (bulkRespose.Items != null)
            {
                return bulkRespose
                    .Items
                    .Select(s => new Models.HitRecord()
                    {
                        IsValid = s.IsValid,
                        Id = s.Id,
                        Index = s.Index,
                        Operation = s.Operation,
                        Status = s.Status,
                        Type = s.Type,
                        Version = s.Version
                    })
                    .ToArray();
            }
            else
            {
                return new Models.HitRecord[0];
            }
        }

        public string BuildIndexName(string baseIndexName, DateTime d)
        {
            return BuildIndexName(baseIndexName, d, this.CurrentSettings.RollingIndexFormat);
        }
        public string BuildIndexName(string baseIndexName, DateTime d, ElasticSettings.RollingIndexFormats format)
        {
            switch (format)
            {
                case ElasticSettings.RollingIndexFormats.Day:
                    return $"{baseIndexName}_{d.ToString("yyyyMMdd")}";
                case ElasticSettings.RollingIndexFormats.Month:
                    return $"{baseIndexName}_{d.ToString("yyyyMM")}";
                case ElasticSettings.RollingIndexFormats.Year:
                    return $"{baseIndexName}_{d.ToString("yyyy")}";
                default:
                    return "";
            }
        }

        public Indices BuildIndexName(string baseIndexName, DateTime fromDate, DateTime toDate, ElasticSettings.RollingIndexFormats format = ElasticSettings.RollingIndexFormats.Month)
        {
            var indicies = "";
            int index = 0;
            while (fromDate <= toDate)
            {
                //check if entire year in the range

                if (index > 0)
                    indicies += ",";

                switch (format)
                {
                    case ElasticSettings.RollingIndexFormats.Day:
                        //if entire year in range add it all..
                        if (fromDate.Day == 1 && fromDate.AddMonths(1) <= toDate)
                        {
                            indicies += BuildIndexName(baseIndexName, fromDate, ElasticSettings.RollingIndexFormats.Month) + "*";
                            fromDate = fromDate.AddMonths(1);
                        }
                        else
                        {
                            indicies += BuildIndexName(baseIndexName, fromDate, ElasticSettings.RollingIndexFormats.Day);
                            fromDate = fromDate.AddDays(1);
                        }
                        break;
                    case ElasticSettings.RollingIndexFormats.Month:
                        //if entire year in range add it all..
                        if (fromDate.Month == 1 && new DateTime(fromDate.Year, 12, 1) <= toDate)
                        {
                            indicies += BuildIndexName(baseIndexName, fromDate, ElasticSettings.RollingIndexFormats.Year) + "*";
                            fromDate = fromDate.AddYears(1);
                        }
                        else
                        {
                            indicies += BuildIndexName(baseIndexName, fromDate, ElasticSettings.RollingIndexFormats.Month);
                            fromDate = fromDate.AddMonths(1);
                        }
                        break;
                    case ElasticSettings.RollingIndexFormats.Year:
                        indicies += BuildIndexName(baseIndexName, fromDate, ElasticSettings.RollingIndexFormats.Year);
                        fromDate = fromDate.AddYears(1);
                        break;
                }

                if (index > this.CurrentSettings.MaxIndexsMultiSearch)
                {
                    return "*";
                }

                index++;
            }

            return indicies == "" ? Indices.All : Indices.Parse(indicies);

        }

        #endregion

        #region protected methods

        protected virtual void DefaultOverrideSearchRequest<T>(SearchRequest<T> request)
        {
            request.AllowNoIndices = true;
            request.IgnoreUnavailable = true;
        }

        #endregion

        #region public methods

        public IGetIndexTemplateResponse GetIndexTemplate(string indexName)
        {
            var request = new GetIndexTemplateRequest(indexName)
            {

            };

            return this._Client.GetIndexTemplate(request);
        }

        public IGetMappingResponse GetMappings(string indexName)
        {
            var request = new GetMappingRequest(Indices.Parse(indexName))
            {
                IgnoreUnavailable = true,
                AllowNoIndices = true
            };

            return this._Client.GetMapping(request);
        }

        #region Delete Index


        public IExistsResponse IsIndexExists(Indices indices, Action<IndexExistsRequest> RequestModify = null)
        {
            var request = new IndexExistsRequest(indices)
            {
                IgnoreUnavailable = false,
                AllowNoIndices = false
            };

            if (RequestModify != null)
            {
                RequestModify(request);
            }

            var response = _Client.IndexExists(request);

            return response;
        }
        public ICreateIndexResponse CreateIndex(string indexName, Action<CreateIndexRequest> RequestAction = null)
        {
            var request = new CreateIndexRequest(indexName);

            if (RequestAction != null)
            {
                RequestAction(request);
            }

            return _Client.CreateIndex(request);
        }
        public IDeleteIndexResponse DeleteIndex(params string[] indexName)
        {
            return DeleteIndex(null, indexName);
        }
        public IDeleteIndexResponse DeleteIndex(Action<DeleteIndexRequest> DeleteIndexRequestModify, params string[] indexName)
        {
            var indices = indexName
                        .Select(i => Indices.Index(i))
                        .ToArray();

            var request = new DeleteIndexRequest(indices);

            if (DeleteIndexRequestModify != null)
            {
                DeleteIndexRequestModify(request);
            }

            return _Client.DeleteIndex(request);
        }

        #endregion

        #region Bulk Index/Create Records

        public IBulkResponse BullkIndex<T>(
            Func<T, string> IndexNameGenerator,
            Func<T, string> TypeNameGenerator,
            IEnumerable<T> jobectS,
            Func<T, string> IdGenerator = null,
            Func<T, string> RoutingValue = null,
            Action<BulkDescriptor> BulkDescriptorModifiy = null) where T : class
        {
            var descriptor = new BulkDescriptor();

            foreach (var j in jobectS)
            {
                descriptor.Index<T>(i =>
                {
                    i = i
                        .Index(IndexNameGenerator(j))
                        .Type(TypeNameGenerator(j))
                        .Timestamp((DateTime.UtcNow.Ticks - DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond)
                        .Document(j);

                    if (IdGenerator != null)
                    {
                        i = i
                        .Id(IdGenerator(j));
                    }

                    if (RoutingValue != null)
                    {
                        i = i.Routing(RoutingValue(j));
                    }

                    return i;
                });
            }

            if (BulkDescriptorModifiy != null)
            {
                BulkDescriptorModifiy(descriptor);
            }

            var result = _Client.Bulk(descriptor);

            return result;
        }

        public IBulkResponse BullkCreate<T>(
            Func<T, string> IndexNameGenerator,
            Func<T, string> TypeNameGenerator,
            IEnumerable<T> jobectS,
            Func<T, string> IdGenerator = null,
            Func<T, string> RoutingValue = null,
            Action<BulkDescriptor> BulkDescriptorModifiy = null) where T : class
        {
            var descriptor = new BulkDescriptor();

            foreach (var j in jobectS)
            {
                descriptor.Create<T>(i =>
                {
                    i = i
                        .Index(IndexNameGenerator(j))
                        .Type(TypeNameGenerator(j))
                        .Document(j);

                    if (IdGenerator != null)
                    {
                        i = i
                        .Id(IdGenerator(j));
                    }

                    if (RoutingValue != null)
                    {
                        i = i.Routing(RoutingValue(j));
                    }

                    return i;
                });
            }

            if (BulkDescriptorModifiy != null)
            {
                BulkDescriptorModifiy(descriptor);
            }

            var result = _Client.Bulk(descriptor);

            return result;
        }

        #endregion

        #region Get/Insert/Delete Single Record
        public IGetResponse<T> GetByID<T>(string indexName, string type, string id, Action<GetRequest<T>> GetRequestModify, Action<IGetResponse<T>, T> RecordsModify, string Routing = null) where T : class
        {
            try
            {
                var request = new GetRequest<T>(indexName, type, id)
                {
                    Routing = Routing
                };

                if (GetRequestModify != null)
                {
                    GetRequestModify(request);
                }

                var response = _Client.Get<T>(request);

                if (RecordsModify != null)
                {
                    RecordsModify(response, response.Source);
                }

                return response;
            }
            catch (Exception e)
            {
                throw e;
            }
        }
        public IIndexResponse IndexRecord<T>(string indexName, string type, T jobect,
            Action<IIndexRequest<T>> IndexRequestModify = null, string Id = null, string routing = null) where T : class
        {
            var request = new IndexRequest<T>(indexName, type, Id)
            {
                Document = jobect,
                Routing = routing,
            };

            if (IndexRequestModify != null)
            {
                IndexRequestModify(request);
            }

            return _Client.Index(request);
        }
        public IDeleteResponse DeleteRecord(string indexName, string type, string Id = null,
            Action<IDeleteRequest> DeleteRequestModifiy = null, string RoutingValue = null)
        {
            var request = new DeleteRequest(indexName, type, Id)
            {
                Routing = RoutingValue
            };

            if (DeleteRequestModifiy != null)
            {
                DeleteRequestModifiy(request);
            }

            return _Client.Delete(request);
        }

        #endregion

        #region Search methods

        public ISearchResponse<T> Search<T>(Indices indices, Types type, Action<IHit<T>, T> RecordsModify = null, Action<SearchRequest<T>> SearchRequestModify = null) where T : class
        {
            var request = new SearchRequest<T>(indices, type);

            DefaultOverrideSearchRequest<T>(request);

            if (SearchRequestModify != null)
            {
                SearchRequestModify(request);
            }

            var searchResults = _Client.Search<T>(request);

            if (RecordsModify != null)
            {
                foreach (var item in searchResults.Hits)
                {
                    RecordsModify(item, item.Source);
                }
            }

            return searchResults;
        }
        public void Search_Fields<T>(SearchRequest<T> request, params string[] FieldsNames)
        {
            request.FielddataFields = FieldsNames;
        }
        public void Search_SortColumns<T>(SearchRequest<T> request, string sortColumns)
        {
            if (!string.IsNullOrEmpty(sortColumns))
            {
                var sortedColumns = sortColumns.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                if (sortedColumns.Length > 0)
                {
                    var cols = sortedColumns
                                    .Select(c => new SortField()
                                    {
                                        Field = c.Substring(0, c.IndexOf(' ')),
                                        Order = c.EndsWith(ELASTIC_SORT_ASCENDING) ? SortOrder.Ascending : SortOrder.Descending
                                    })
                                    .ToArray();

                    _Search_sort(request, cols);
                }
            }
        }
        public void Search_BuildRange<T>(SearchRequest<T> request, string field, DateTime? from, DateTime? to, double? BoostValue = null)
        {
            Search_BuildRange<T>(request, field,
                                                from.HasValue ? ((from.Value.Ticks - DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond) : (long?)null,
                                                to.HasValue ? ((to.Value.Ticks - DATETIME_UNIX_1970_1JAN) / TimeSpan.TicksPerMillisecond) : (long?)null,
                                    BoostValue);
        }
        public void Search_LocationRange<T>(SearchRequest<T> request, string field, double lat, double lon, double Distance, DistanceUnit unit = DistanceUnit.Kilometers)
        {
            var range = new GeoDistanceQuery()
            {
                Boost = 1.5,
                Field = field,
                Distance = new Distance(Distance, unit),
                Location = new GeoLocation(lat, lon)
            };
            request.Query = request.Query && range;

        }
        public void Search_Location_SortLocation<T>(SearchRequest<T> request, string field, double lat, double lon,
             DistanceUnit unit = DistanceUnit.Kilometers,
             SortOrder order = SortOrder.Ascending)
        {
            var geoSort = new GeoDistanceSort()
            {
                Field = field,
                GeoUnit = unit,
                Order = order,
                Points = new GeoLocation[]
                 {
                     new GeoLocation(lat,lon)
                 },
                DistanceType = GeoDistanceType.Plane,
            };

            _Search_sort(request, geoSort);
        }

        private void _Search_sort<T>(SearchRequest<T> request, params ISort[] sorts)
        {
            if (request.Sort == null)
            {
                request.Sort = new List<ISort>();
            }

            foreach (var s in sorts)
            {
                request.Sort.Add(s);
            }
        }

        public void Search_BuildRange<T>(SearchRequest<T> request, string field, long? from, long? to, double? BoostValue = null)
        {
            if (from.HasValue || to.HasValue)
            {
                var range = new NumericRangeQuery()
                {
                    Boost = BoostValue,
                    Field = field,
                    GreaterThanOrEqualTo = from.HasValue ? from.Value : (double?)null,
                    LessThanOrEqualTo = to.HasValue ? to.Value : (double?)null
                };

                request.Query = request.Query && range;
            }

        }
        public void Search_Paging<T>(SearchRequest<T> request, int PageSize, int PageNumber)
        {
            request.From = (PageNumber - 1) * PageSize;
            request.Size = PageSize;
        }

        /// <summary>
        /// Used to search on not-analyzed.
        /// </summary>
        public void Search_Term<T>(SearchRequest<T> request, string field, object value, string TermName = null)
        {
            var t = new TermQuery()
            {
                Name = TermName ?? $"TermQuery-{field}",
                Field = field,
                Value = value
            };

            request.Query = request.Query && t;
        }

        /// <summary>
        /// Used to search on analyzed and not analyzed fields. Usually useful for analyzed fields.
        /// ATTENTION:: the search treat symbols like @, *, - expressions....
        /// </summary>
        /// <param name="query">search query. can be used with Operators like AND, OR...</param>
        public void SearchMatch<T>(SearchRequest<T> request, string field, string query, string TermName = null)
        {
            var d = new QueryStringQuery()
            {
                Fields = Field.Create(field),
                Query = query
            };

            request.Query = request.Query && d;
        }

        #endregion

        #endregion

        #region IDisposable members

        public virtual void Dispose()
        {
            _Client = null;
        }

        #endregion
    }
}


